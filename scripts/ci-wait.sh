#!/usr/bin/env bash
# Usage: scripts/ci-wait.sh <workflow-file>   e.g. scripts/ci-wait.sh core-tests.yml
set -euo pipefail
wf="$1"
sha=$(git rev-parse HEAD)
id=""
for _ in $(seq 1 36); do
  id=$(gh run list --workflow "$wf" --commit "$sha" --limit 1 --json databaseId -q '.[0].databaseId' || true)
  [ -n "$id" ] && break
  sleep 5
done
[ -n "$id" ] || { echo "no run found for $wf at $sha"; exit 2; }
if gh run watch "$id" --exit-status >/dev/null; then
  echo "PASS $wf ($id)"
else
  gh run view "$id" --log-failed | tail -n 80
  echo "FAIL $wf ($id)"
  exit 1
fi
