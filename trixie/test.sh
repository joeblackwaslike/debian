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

name=tiny-sigterm-$$
docker run -d --name "$name" "$IMAGE" bash -c 'sleep 60' >/dev/null
sleep 1
run bash -c '/usr/sbin/policy-rc.d; test $? -eq 101'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && ! ls /var/lib/apt/lists | grep -qE "_(Packages|Sources|Release)$"'
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends jq >/dev/null && apt-get -s autoremove | grep -q "^0 upgraded, 0 newly installed, 0 to remove"'

start=$(date +%s)
docker stop -t 20 "$name" >/dev/null
docker rm "$name" >/dev/null
(( $(date +%s) - start < 5 )) || { echo "SIGTERM not forwarded"; exit 1; }

echo "uncompressed: $(docker image inspect "$IMAGE" --format '{{.Size}}' | awk '{printf "%.1f MB", $1/1e6}')"
echo "compressed:   $(docker save "$IMAGE" | gzip -c | wc -c | awk '{printf "%.1f MB", $1/1e6}')"
echo PASS
