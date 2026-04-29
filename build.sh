#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAPPE_DOCKER_DIR="$(realpath "$SCRIPT_DIR/../frappe_docker")"

INSTANCE="${1:-erpnext}"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

CUSTOM_IMAGE=$(grep '^CUSTOM_IMAGE=' "$ENV_FILE" | cut -d= -f2-)
CUSTOM_TAG=$(grep '^CUSTOM_TAG=' "$ENV_FILE" | cut -d= -f2-)

# By default all layers are rebuilt from scratch (--no-cache) to guarantee a
# clean image. Pass --fast to only bust the bench init layer and reuse cached
# OS/dependency layers — useful when iterating on apps.json without a
# Containerfile change.
FAST=false
for arg in "$@"; do
  [[ "$arg" == "--fast" ]] && FAST=true
done

if [[ "$FAST" == true ]]; then
  CACHE_OPTS=(--build-arg "CACHE_BUST=$(date +%s)")
else
  CACHE_OPTS=(--no-cache)
fi

docker build \
  --secret id=apps_json,src="$SCRIPT_DIR/apps.json" \
  --tag="${CUSTOM_IMAGE}:${CUSTOM_TAG}" \
  "${CACHE_OPTS[@]}" \
  --file="$FRAPPE_DOCKER_DIR/images/custom/Containerfile" \
  "$FRAPPE_DOCKER_DIR"

echo ""
echo "Image built: ${CUSTOM_IMAGE}:${CUSTOM_TAG}"
echo ""
echo "Tip: pass --fast to reuse cached OS/dependency layers (only busts bench init)."
echo ""
echo "Note: after deploying this image, run ./sync-assets.sh if assets do not"
echo "load correctly in the browser (CSS/JS 404s). This syncs assets.json with"
echo "the new image's hashed files without a full recompile."
