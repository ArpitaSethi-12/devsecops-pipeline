#!/usr/bin/env bash
# Runs on the EC2 server after a git pull: rebuilds the app and checks it is healthy.
set -euo pipefail
cd /opt/app

sed -i "s/^APP_VERSION=.*/APP_VERSION=$(git rev-parse --short HEAD)/" .env
docker compose -f docker-compose.prod.yml up -d --build
docker image prune -f >/dev/null

for i in $(seq 1 20); do
  if curl -sf http://localhost/health; then
    echo
    echo "EC2 is healthy"
    exit 0
  fi
  echo "Waiting for the app ($i/20)..."
  sleep 3
done
echo "EC2 health check failed"
exit 1
