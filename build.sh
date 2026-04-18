#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAPPE_DOCKER_DIR="$(realpath "$SCRIPT_DIR/../frappe_docker")"

INSTANCE="${1:-erpnext}"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

CUSTOM_IMAGE=$(grep '^CUSTOM_IMAGE=' "$ENV_FILE" | cut -d= -f2-)
CUSTOM_TAG=$(grep '^CUSTOM_TAG=' "$ENV_FILE" | cut -d= -f2-)

docker build \
  --secret id=apps_json,src="$SCRIPT_DIR/apps.json" \
  --tag="${CUSTOM_IMAGE}:${CUSTOM_TAG}" \
  --no-cache \
  --file="$FRAPPE_DOCKER_DIR/images/custom/Containerfile" \
  "$FRAPPE_DOCKER_DIR"
