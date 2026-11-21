# debian-tiny (Debian 13 trixie)

[![CI](https://github.com/joeblackwaslike/debian/actions/workflows/ci.yml/badge.svg)](https://github.com/joeblackwaslike/debian/actions/workflows/ci.yml)

A small glibc Debian base image with bash, dpkg, apt and working HTTPS. It is built from an explicit package list instead of Debian's minbase set, then stripped of docs, man pages, locales, extra charsets and apt caches.

Measured on arm64 against `debian:trixie-slim`:

| | Compressed | On disk |
|---|---|---|
| `debian:trixie-slim` | 30.2MB | 104MB |
| debian-tiny | 22.5MB | 62MB |

The amd64 build is about the same size. Before openssl was added back it measured 22.8MB compressed and 57MB on disk, against 29.9MB and 83MB for the amd64 slim image. I have not re-measured it since.

"Compressed" is `docker save | gzip`. Docker's own size column reads about 25MB higher than `du` here and I never found out why, so I don't quote it.

## What is in it

- 19 packages chosen by hand, about 50 installed with dependencies: bash, apt, dpkg, ca-certificates, base-files, base-passwd, coreutils, dash, grep, sed, tar, gzip, findutils, debconf, libc-bin, mawk, diffutils, perl-base and init-system-helpers.
- [dumb-init](https://github.com/Yelp/dumb-init) 1.2.5 as the entrypoint.
- [gosu](https://github.com/tianon/gosu) 1.20 for dropping root.
- openssl and the CA bundle. apt sources point at `https://deb.debian.org`.
- A `policy-rc.d` that exits 101, so installing a service package does not try to start the daemon.
- apt set to skip recommends and suggests, keep package indexes gzipped, and not treat recommends or suggests as reasons to keep a package on autoremove.
- A `docker-clean` apt config, copied from Debian's official images. After every dpkg run and every `apt-get update` it deletes downloaded `.deb` files, and apt never writes `pkgcache.bin` or `srcpkgcache.bin`.
- The shell setup from the old image, for interactive bash. The prompt follows my local oh-my-posh theme on two lines, `user in /full/path` and then `host ❯`, with a Nerd Font root marker when running as root. The setup also adds `ls` and `grep` color aliases, `LANG=C.UTF-8`, and the log, linux, shell and net helper functions in `/etc/profile.d/40-functions.sh`. `~/.bashrc` runs the `/etc/profile.d` scripts, so a plain `docker run -it` shell gets all of it.
- `path-helper` and `fixattrs`. `path-helper` puts every directory listed in `/etc/paths.d/*` that exists and is not already on `PATH` in front of `PATH`, and `~/bin` is listed by default. `fixattrs` reads `path recursive user:group fmode dmode` lines from `/etc/fixattrs.d/*` and applies them. It skips blank lines and lines starting with `#`, and it exits 1 for a malformed rule, a path that does not exist, or a failed `chown` or `chmod`. A rule with `recursive` set to `false` changes only the path itself. It refuses the system directories it lists, such as `/etc` and `/usr`, but not what is under them, so it only catches typos and shouldn't be your security boundary. Login shells source every file in `/etc/environment.d/` and export what they set. These are shell fragments, not systemd's `KEY=value` format.

Images built on this one should stay small too. Without `docker-clean`, `apt-get install jq` leaves three `.deb` files and both binary caches in the layer. `docker-clean` does the same as `apt-get clean` and keeps the package indexes in `/var/lib/apt/lists`, so `apt-get install a && apt-get install b` still works in one `RUN`. End that `RUN` with `rm -rf /var/lib/apt/lists/*` to drop the indexes. To keep the `.deb` files, delete `/etc/apt/apt.conf.d/docker-clean`.

dumb-init and gosu are downloaded at build time and checked against pinned sha256 sums for amd64 and arm64.

## Build

```sh
docker build -t debian-tiny:trixie .
docker buildx build --platform linux/amd64,linux/arm64 -t debian-tiny:trixie .
```

The build needs network access and takes a few minutes. Every push to master that changes more than Markdown files publishes a multi-arch image (amd64 and arm64) to Docker Hub as `joeblackwaslike/debian-tiny`. Every publish gets `latest`, `trixie` and a `sha-<short commit>` tag. Runs queue one at a time, and when several pushes land while one is running only the newest waits, so an older commit's `sha-` tag can be skipped. Re-running an old run from the Actions tab republishes that commit as `latest`. Each architecture builds on a native runner without a cache, and the pushed image is pulled back and tested with `test.sh` before any tag is created. You can also run it by hand from the Actions tab to pick up new Debian security updates. It needs the `DOCKERHUB_USERNAME` repository variable and a `DOCKERHUB_TOKEN` secret in the `dockerhub` environment.

## Use

```sh
docker pull joeblackwaslike/debian-tiny:trixie
docker run --rm -it debian-tiny:trixie
docker run --rm debian-tiny:trixie gosu nobody id -u
```

The entrypoint is `dumb-init --` and the default command is `bash`.

## Test

```sh
./test.sh debian-tiny:trixie
```

The script runs the image and checks that bash and dumb-init run, `dpkg --audit` is clean, and apt can update and install jq, curl, tzdata, cron and adduser. It also checks gosu, `--user`, `policy-rc.d`, gzipped indexes, autoremove, that installs leave no `.deb` files or binary caches behind, openssl, `path-helper`, `fixattrs`, the interactive prompt and aliases, `container-id`, an HTTPS apt fetch, certificate verification (github.com loads, a self-signed host is rejected) and SIGTERM forwarding. It ends by printing both sizes. The SIGTERM check failed once when I ran the amd64 image under emulation on an arm64 Mac, and I did not look into why.

## How it is built

1. `mmdebstrap --variant=custom` installs the package list and its dependencies into `/rootfs`, with dpkg `path-exclude` rules so docs, man pages, info and locale files are never unpacked.
2. The [overlay/](overlay) tree (the shell setup, `path-helper` and `fixattrs`) is copied onto `/rootfs`, then dumb-init, gosu, the apt config, `policy-rc.d`, `/etc/dircolors` and `/root`'s skel files go in.
3. [strip.sh](strip.sh) removes what is left: apt lists and caches, logs, most gconv charsets (UTF-8, UTF-16, UTF-32 and ISO-8859-1 stay), perl unicore tables, extra zoneinfo, bash completion and debconf caches.
4. A `FROM scratch` stage copies the rootfs into the final image.

The first attempt used `--variant=minbase` and landed only a few MB under `trixie-slim`, because minbase installs every Essential package. Building from a list got the size down. A custom list needs three packages that minbase supplies for free. dpkg wants `diff` (diffutils), the debconf and libc6 postinst scripts run perl (perl-base), and the apt and dpkg postinst scripts call `deb-systemd-helper` (init-system-helpers).

## Why it is not smaller

The floor is set by libc6 (24MB installed), coreutils (21MB), libssl3t64 (8MB), perl-base (8MB), bash (7MB) and dpkg plus apt (12MB). Those are all code that something runs or links.

Things tried and left out:

- Dropping grep, gzip and findutils saves about 1MB, but `passwd.postinst` calls grep, so package installs break.
- Adding util-linux for `setpriv` costs 16MB on disk, which is why gosu is here instead.
- UPX on the binaries would cut disk size but barely changes the compressed size.
- Skipping dependencies with `dpkg --force-depends`, as the old build did, would drop libsystemd0, libudev1 and the nettle libraries for about 3MB, at the cost of a dpkg database with unmet dependencies. Not done.

## What the old image had that this one does not

The jessie and stretch image (last present at [99d68eb](https://github.com/joeblackwaslike/debian/tree/99d68eb)) also shipped goss, the other container-utils scripts (kube-hostname-fix, kube-search-domains, erlang-cookie, set-limits, detect-proxy), the kube, kazoo and erlang helper functions, liboverridehostname and the `/etc/entrypoint.d` layout. None of that is ported. The old build also drove debootstrap through TurnKey's fab and chanko tools, which do not run on trixie.

The shell setup above comes from that image's `unit.d` and from [container-utils v0.2](https://github.com/telephoneorg/container-utils/tree/v0.2). I fixed some bugs while porting it. `linux::cmd::does-not-exist` was missing its `!`, `net::is-short-hostname` called a function that did not exist, `net::is-long-hostname` called the missing `hostname` binary, and `container-id` only understood cgroup v1 without the systemd driver. The bash-only scripts now skip themselves under dash, so `sh -l` still works, and a `TERM` you pass in is kept. The `environment.d` loader moved from `/etc/environment` into `/etc/profile.d/60-build-environment.sh`, because PAM reads `/etc/environment` as plain `NAME=VALUE` lines. `fixattrs` now exits 1 when a `chown` or `chmod` fails. `~/.bashrc` runs the `/etc/profile.d` scripts directly instead of `/etc/profile`, so a `PATH` you pass to `docker run -e` survives. `get-ipv4` and `net::get-mtu` need iproute2, and `linux::cap::is-enabled` needs libcap2-bin.
