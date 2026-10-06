#!/usr/bin/env bash
# Checks that the deployed API is healthy and running the expected version.
set -euo pipefail
: "${NAMESPACE:?NAMESPACE is required}"
: "${IMAGE:?IMAGE is required}"
EXPECTED="${IMAGE##*:}"

kubectl -n "$NAMESPACE" port-forward svc/api 8080:80 >/dev/null 2>&1 &
PF_PID=$!
trap 'kill $PF_PID 2>/dev/null || true' EXIT

for i in $(seq 1 20); do
  if body=$(curl -sf http://127.0.0.1:8080/health); then
    echo "Health response: $body"
    status=$(echo "$body" | jq -r .status)
    version=$(echo "$body" | jq -r .version)
    if [[ "$status" == "ok" && "$version" == "$EXPECTED" ]]; then
      echo "Smoke test passed: version $version is healthy"
      exit 0
    fi
  fi
  echo "Waiting for API ($i/20)..."
  sleep 3
done

echo "Smoke test failed: expected healthy version $EXPECTED"
exit 1
