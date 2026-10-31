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

run openssl version | grep -q '^OpenSSL 3'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update 2>&1 | grep -q "Get:1 https://deb.debian.org"'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends curl >/dev/null && curl -fsS -o /dev/null https://github.com; curl -sS --max-time 15 https://self-signed.badssl.com/ -o /dev/null; rc=$?; echo "curl_rc=$rc"; test "$rc" -eq 60'

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
