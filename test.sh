#!/usr/bin/env bash
set -euo pipefail
IMAGE=${1:?usage: test.sh IMAGE}
run() { docker run --rm "$IMAGE" "$@"; }

run bash -c 'echo ok' | grep -qx ok
run dumb-init --version 2>&1 | grep -q 1.2.5
run bash -c 'dpkg --audit | wc -l' | grep -qx 0
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends jq >/dev/null && jq --version'
run gosu nobody id -u | grep -qx 65534
run gosu --version | grep -q '^1.20'
docker run --rm --user 65534:65534 "$IMAGE" id -u | grep -qx 65534
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends curl tzdata cron adduser >/dev/null && curl --version | head -1'

run bash -c '/usr/sbin/policy-rc.d; test $? -eq 101'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && ! ls /var/lib/apt/lists | grep -qE "_(Packages|Sources|Release)$"'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends jq >/dev/null && apt-get -s autoremove | grep -q "^0 upgraded, 0 newly installed, 0 to remove"'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends jq >/dev/null && ! ls /var/cache/apt/archives/*.deb /var/cache/apt/*.bin 2>/dev/null | grep -q .'

run bash -c 'mkdir -p ~/bin && path-helper' | grep -q '^PATH=/root/bin:'
run bash -lc 'mkdir -p ~/bin; exec bash -lc "echo \$PATH"' | grep -q '^/root/bin:'
run bash -ec 'mkdir -p /tmp/x; touch /tmp/x/f; echo "/tmp/x true nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c "%U %a" /tmp/x /tmp/x/f' | tr '\n' ' ' | grep -qx 'nobody 750 nobody 640 '
out=$(docker run --rm -t "$IMAGE" bash -ic 'type -t log::m-info; alias ls; echo "LANG=$LANG"; echo "LS_COLORS=${LS_COLORS:+set}"; echo "$PS1"' 2>/dev/null | tr -d '\r')
grep -qx function <<<"$out"
grep -q -- '--color=auto' <<<"$out"
grep -qx 'LANG=C.UTF-8' <<<"$out"
grep -qx 'LS_COLORS=set' <<<"$out"
grep -qF '\u ' <<<"$out"
grep -qF '\w' <<<"$out"
grep -qF '\h ' <<<"$out"
grep -qF '❯' <<<"$out"
run bash -lc container-id | grep -qE '^[0-9a-f]{12}$'
test "$(run sh -lc 'echo ok' 2>&1)" = ok
quiet=$(run bash -c 'mv /etc/paths.d /tmp/; echo "# comment" > /etc/environment.d/c; bash -lc true' 2>&1)
test -z "$quiet"
docker run --rm -t -e TERM=screen-256color "$IMAGE" bash -ic 'echo "$TERM"' 2>/dev/null | tr -d '\r' | grep -qx screen-256color
run bash -c 'echo FOO=bar > /etc/environment.d/foo; bash -lc "env"' | grep -qx FOO=bar
run bash -c 'mkdir -p /tmp/y; echo "/tmp/y false nosuchuser:nogroup 0640 0750" > /etc/fixattrs.d/t; ! fixattrs >/dev/null 2>&1'
run bash -c 'echo "/tmp/.. true nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c "%U %a" / /etc' | tr '\n' ' ' | grep -qx 'root 755 root 755 '
run bash -c 'mkdir -p /tmp/z; printf "%s" "/tmp/z false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c %U /tmp/z' | grep -qx nobody
run bash -c 'mkdir -p /tmp/n; printf "%s" /tmp/n > /etc/paths.d/n; path-helper' | grep -q '^PATH=/tmp/n:'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends libcap2-bin >/dev/null && bash -lc "linux::cap::is-enabled chown && linux::cap::is-disabled net_admin"'
run bash -c 'mkdir "/tmp/sp ace"; ln -s "/tmp/sp ace" /tmp/lnk; echo "/tmp/lnk true nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c %U "/tmp/sp ace"' | grep -qx nobody
run bash -c 'mkdir "/tmp/g*" /tmp/gx; echo "/tmp/g* true nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c %U "/tmp/g*" /tmp/gx' | tr '\n' ' ' | grep -qx 'nobody root '
run bash --login -e -o pipefail -c 'echo ok' | grep -qx ok
run bash -u -lc 'echo ok' | grep -qx ok
run bash -c 'mkdir "/tmp/my tools"; echo "/tmp/my tools" > /etc/paths.d/s; path-helper' | grep -q '^PATH=/tmp/my tools:'
run env PATH='/tmp/p q:/usr/bin:/bin' /usr/local/bin/path-helper | grep -q '^PATH=/tmp/p q:'
run sh -lec 'echo ok' | grep -qx ok
run bash -c 'mkdir /tmp/ok1; echo "/tmp/ok1 false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1'
run bash -c 'echo "/tmp/missing false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; ! fixattrs >/dev/null 2>&1'
run bash -c 'mkdir /tmp/bm; echo "/tmp/bm false nobody:nogroup zzz 0750" > /etc/fixattrs.d/t; ! fixattrs >/dev/null 2>&1; stat -c %U /tmp/bm' | grep -qx root
run bash -c 'mkdir /tmp/cm; printf "# note\n\n/tmp/cm false nobody:nogroup 0640 0750\n" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1 && stat -c %U /tmp/cm' | grep -qx nobody
run bash -c 'mkdir /tmp/ur; chown nobody /tmp/ur; echo "/tmp/ur false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; chmod 600 /etc/fixattrs.d/t; ! gosu nobody fixattrs >/dev/null 2>&1'
run bash -c 'for p in /etc/ /usr/local /proc/1 /boot; do echo "$p false nobody:nogroup 0640 0750"; done > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c %U /etc /usr/local /boot' | tr '\n' ' ' | grep -qx 'root root root '
run bash -c 'mkdir /tmp/nr; touch /tmp/nr/f; chmod 600 /tmp/nr/f; echo "/tmp/nr false nobody:nogroup 0644 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c %a /tmp/nr/f' | grep -qx 600
run bash -c 'mkdir /root/td; echo "~/td false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c %U /root/td' | grep -qx nobody
run bash -c 'mkdir /tmp/nl; echo "/tmp/nl false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; env -i /bin/bash /usr/local/bin/fixattrs 2>&1' | grep 'Applying ownership' >/dev/null
run bash -c 'mkdir /tmp/d1; echo /tmp/d1 > /etc/paths.d/a; echo /tmp/d1 > /etc/paths.d/b; path-helper' | grep -o /tmp/d1 | wc -l | tr -d ' ' | grep -qx 1
run env HOME='/tmp/a&b' bash -c 'mkdir -p "/tmp/a&b/bin"; echo "~/bin" > /etc/paths.d/h; path-helper' | grep -qF 'PATH=/tmp/a&b/bin:'
run bash -c 'touch /tmp/afile; echo /tmp/afile > /etc/paths.d/f; ! path-helper | grep -q afile'
run bash -uc '. /etc/profile.d/40-functions.sh; log::info x; log::m-warn y' >/dev/null 2>&1
run env PATH=/tmp/zz:/usr/bin:/bin:/usr/sbin:/sbin bash -ic 'echo $PATH' 2>/dev/null | grep -q '^/tmp/zz:'
run bash -c 'test "$(stat -c %a /etc/skel/.bashrc)" = 644'
run bash -lc 'linux::cap::is-enabled chown; test $? -eq 2'
test "$(run bash -ic 'type -t clear' 2>/dev/null)" = function
run bash -c 'echo "/var/lock false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; fixattrs >/dev/null 2>&1; stat -c %U /run/lock' | grep -qx root
run env -u HOME bash -c 'mkdir -p /srv; echo "~/srv false nobody:nogroup 0640 0750" > /etc/fixattrs.d/t; /usr/local/bin/fixattrs >/dev/null 2>&1; stat -c %U /srv' | grep -qx root
run env PATH=/usr/bin: /usr/local/bin/path-helper | grep -q '^PATH=.*:$'
run bash -c 'mkdir ~/bin; PATH= /usr/local/bin/path-helper' | grep -qx 'PATH=/root/bin'
run bash -uc '. /etc/profile.d/40-functions.sh; linux::cap::show-warning net_admin' >/dev/null 2>&1
run env -u HOME bash -c 'echo "~/tmp" > /etc/paths.d/h; ! /usr/local/bin/path-helper | grep -q "^PATH=/tmp:"'

run openssl version | grep -q '^OpenSSL 3'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update 2>&1 | grep -q "Get:1 https://deb.debian.org"'
run bash -ec 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; apt-get install -y -qq --no-install-recommends curl >/dev/null; curl -fsS -o /dev/null https://github.com; rc=0; curl -sS --max-time 15 https://self-signed.badssl.com/ -o /dev/null || rc=$?; echo "curl_rc=$rc"; test "$rc" -eq 60'

name=tiny-sigterm-$$
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; }
trap cleanup EXIT

docker run -d --name "$name" "$IMAGE" bash -c 'sleep 60' >/dev/null
sleep 1
[ "$(docker inspect -f '{{.State.Running}}' "$name")" = true ] || { echo "container exited before stop"; exit 1; }

start=$(date +%s)
docker stop -t 20 "$name" >/dev/null
elapsed=$(( $(date +%s) - start ))
docker rm "$name" >/dev/null
(( elapsed < 5 )) || { echo "SIGTERM not forwarded"; exit 1; }

echo "uncompressed: $(docker image inspect "$IMAGE" --format '{{.Size}}' | awk '{printf "%.1f MB", $1/1e6}')"
echo "compressed:   $(docker save "$IMAGE" | gzip -c | wc -c | awk '{printf "%.1f MB", $1/1e6}')"
echo PASS
