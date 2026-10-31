# debian-tiny (Debian 13 trixie)

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

dumb-init and gosu are downloaded at build time and checked against pinned sha256 sums for amd64 and arm64.

## Build

```sh
docker build -t debian-tiny:trixie .
docker buildx build --platform linux/amd64,linux/arm64 -t debian-tiny:trixie .
```

The build needs network access and takes a few minutes. Nothing is published to a registry yet.

## Use

```sh
docker run --rm -it debian-tiny:trixie
docker run --rm debian-tiny:trixie gosu nobody id -u
```

The entrypoint is `dumb-init --` and the default command is `bash`.

## Test

```sh
./test.sh debian-tiny:trixie
```

The script runs the image and checks that bash and dumb-init run, `dpkg --audit` is clean, and apt can update and install jq, curl, tzdata, cron and adduser. It also checks gosu, `--user`, `policy-rc.d`, gzipped indexes, autoremove, openssl, an HTTPS apt fetch, certificate verification (github.com loads, a self-signed host is rejected) and SIGTERM forwarding. It ends by printing both sizes. The SIGTERM check failed once when I ran the amd64 image under emulation on an arm64 Mac, and I did not look into why.

## How it is built

1. `mmdebstrap --variant=custom` installs the package list and its dependencies into `/rootfs`, with dpkg `path-exclude` rules so docs, man pages, info and locale files are never unpacked.
2. [strip.sh](strip.sh) removes what is left: apt lists and caches, logs, most gconv charsets (UTF-8, UTF-16, UTF-32 and ISO-8859-1 stay), perl unicore tables, extra zoneinfo, bash completion and debconf caches.
3. dumb-init, gosu, the apt config and `policy-rc.d` go in.
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

The jessie and stretch image (last present at [99d68eb](https://github.com/joeblackwaslike/debian/tree/99d68eb)) also shipped goss, the container-utils scripts, liboverridehostname and the `/etc/entrypoint.d`, `/etc/profile.d` and `/etc/paths.d` layout. None of that is ported. The old build also drove debootstrap through TurnKey's fab and chanko tools, which do not run on trixie.
