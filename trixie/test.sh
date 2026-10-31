#!/usr/bin/env bash
set -euo pipefail
IMAGE=${1:?usage: test.sh IMAGE}
run() { docker run --rm "$IMAGE" "$@"; }

run bash -c 'echo ok' | grep -qx ok
run dumb-init --version 2>&1 | grep -q 1.2.5
run bash -c 'dpkg --audit | wc -l' | grep -qx 0
run bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq --no-install-recommends jq >/dev/null && jq --version'
run bash -c 'setpriv --reuid=nobody --regid=nogroup --clear-groups id -u' | grep -qx 65534

name=tiny-sigterm-$$
docker run -d --name "$name" "$IMAGE" bash -c 'sleep 60' >/dev/null
sleep 1
start=$(date +%s)
docker stop -t 20 "$name" >/dev/null
docker rm "$name" >/dev/null
(( $(date +%s) - start < 5 )) || { echo "SIGTERM not forwarded"; exit 1; }

echo "uncompressed: $(docker image inspect "$IMAGE" --format '{{.Size}}' | awk '{printf "%.1f MB", $1/1e6}')"
echo "compressed:   $(docker save "$IMAGE" | gzip -c | wc -c | awk '{printf "%.1f MB", $1/1e6}')"
echo PASS
