#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAPPE_DOCKER_DIR="$(realpath "$SCRIPT_DIR/../frappe_docker")"

INSTANCE="${1:-erpnext}"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

source "$ENV_FILE"

docker build \
  --secret id=apps_json,src="$SCRIPT_DIR/apps.json" \
  --tag="${CUSTOM_IMAGE}:${CUSTOM_TAG}" \
  --no-cache \
  --file="$FRAPPE_DOCKER_DIR/images/custom/Containerfile" \
  "$FRAPPE_DOCKER_DIR"
