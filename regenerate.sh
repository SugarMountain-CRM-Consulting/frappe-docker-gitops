#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAPPE_DOCKER_DIR="$(realpath "$SCRIPT_DIR/../frappe_docker")"

INSTANCE="${1:-erpnext}"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: ${INSTANCE}.env not found. Run ./initialize.sh ${INSTANCE} first." >&2
  exit 1
fi

echo "Regenerating ${INSTANCE}.yaml from ${INSTANCE}.env..."

docker compose \
  --project-name "$INSTANCE" \
  --env-file "$ENV_FILE" \
  -f "$FRAPPE_DOCKER_DIR/compose.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.mariadb.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.redis.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.nginxproxy.yaml" \
  config > "$SCRIPT_DIR/${INSTANCE}.yaml"

echo "Done: ${INSTANCE}.yaml"
