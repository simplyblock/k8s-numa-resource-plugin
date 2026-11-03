#!/usr/bin/env bash
# Runs Red Hat's preflight container checks on a pushed image for amd64 and
# arm64, and fails when any check fails. preflight exits 0 either way, so the
# verdict is read from its results.json. Usage: hack/preflight.sh <image@digest>
set -euo pipefail

IMAGE="$1"
PREFLIGHT_VERSION="1.22.0"
PREFLIGHT_SHA256="1451ed8763f209f4d4a63848d9d62d1d40653a247db43d7606feb28eadbbd99b"

curl -fsSL -o preflight \
  "https://github.com/redhat-openshift-ecosystem/openshift-preflight/releases/download/${PREFLIGHT_VERSION}/preflight-linux-amd64"
echo "${PREFLIGHT_SHA256}  preflight" | sha256sum -c -
chmod +x preflight

failed=0
for platform in amd64 arm64; do
  ./preflight check container "$IMAGE" --platform "$platform" --artifacts preflight-artifacts > /dev/null
  result="preflight-artifacts/${platform}/results.json"
  if [ "$(jq -r .passed "$result")" != "true" ]; then
    echo "::error::preflight failed for ${IMAGE} (${platform})"
    jq -r '.results.failed[], .results.errors[] | "  \(.name): \(.suggestion // .help // "")"' "$result"
    failed=1
  fi
done
exit "$failed"
