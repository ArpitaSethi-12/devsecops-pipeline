#!/usr/bin/env bash
# Deploys Postgres and the API into a namespace.
# Needs: NAMESPACE, IMAGE. Optional: DB_PASSWORD.
set -euo pipefail
: "${NAMESPACE:?NAMESPACE is required}"
: "${IMAGE:?IMAGE is required}"
VERSION="${IMAGE##*:}"

echo "Deploying $IMAGE to namespace $NAMESPACE"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create the DB password secret once. Changing it later would lock the app out of an existing database.
if ! kubectl -n "$NAMESPACE" get secret db-credentials >/dev/null 2>&1; then
  PASSWORD="${DB_PASSWORD:-$(openssl rand -hex 16)}"
  kubectl -n "$NAMESPACE" create secret generic db-credentials --from-literal=password="$PASSWORD"
fi

kubectl -n "$NAMESPACE" apply -f k8s/postgres.yaml
kubectl -n "$NAMESPACE" rollout status deployment/postgres --timeout=180s

sed -e "s|IMAGE_PLACEHOLDER|$IMAGE|" -e "s|VERSION_PLACEHOLDER|$VERSION|" k8s/api.yaml \
  | kubectl -n "$NAMESPACE" apply -f -
kubectl -n "$NAMESPACE" rollout status deployment/api --timeout=180s
