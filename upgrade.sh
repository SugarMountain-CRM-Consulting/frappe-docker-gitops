#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAPPE_DOCKER_DIR="$(realpath "$SCRIPT_DIR/../frappe_docker")"

INSTANCE="${1:-erpnext}"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

# ── Pull latest frappe_docker ─────────────────────────────────────────────────

echo "Pulling latest frappe_docker..."
git -C "$FRAPPE_DOCKER_DIR" pull

# ── Prompt for new image tag ──────────────────────────────────────────────────

CURRENT_TAG=$(grep '^CUSTOM_TAG=' "$ENV_FILE" | cut -d= -f2-)
read -rp "New image tag [$CURRENT_TAG]: " NEW_TAG
NEW_TAG="${NEW_TAG:-$CURRENT_TAG}"

if [[ "$NEW_TAG" != "$CURRENT_TAG" ]]; then
  sed -i "s|CUSTOM_TAG=.*|CUSTOM_TAG=${NEW_TAG}|" "$ENV_FILE"
  echo "Updated CUSTOM_TAG → $NEW_TAG"
fi

# ── Rebuild image ─────────────────────────────────────────────────────────────

echo ""
echo "Building image..."
"$SCRIPT_DIR/build.sh" "$INSTANCE"

# ── Regenerate compose config ─────────────────────────────────────────────────

echo ""
echo "Regenerating ${INSTANCE}.yaml..."

docker compose \
  --env-file "$ENV_FILE" \
  -f "$FRAPPE_DOCKER_DIR/compose.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.mariadb.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.redis.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.nginxproxy.yaml" \
  config > "$SCRIPT_DIR/${INSTANCE}.yaml"

# ── Recreate containers ───────────────────────────────────────────────────────

echo ""
echo "Recreating containers..."
docker compose -f "$SCRIPT_DIR/${INSTANCE}.yaml" up -d --force-recreate

# ── Migrate ───────────────────────────────────────────────────────────────────

echo ""
echo "Running migrations..."
"$SCRIPT_DIR/migrate.sh" "$INSTANCE"

echo ""
echo "Upgrade complete."
