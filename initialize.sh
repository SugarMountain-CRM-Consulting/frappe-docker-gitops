#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAPPE_DOCKER_DIR="$(realpath "$SCRIPT_DIR/../frappe_docker")"

# ── Prerequisites ─────────────────────────────────────────────────────────────

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "Error: '$1' is required but not installed." >&2
    exit 1
  fi
}

check_cmd docker
check_cmd git
check_cmd openssl
docker compose version &>/dev/null || { echo "Error: 'docker compose' plugin is required." >&2; exit 1; }

# ── Clone frappe_docker if missing ────────────────────────────────────────────

if [[ ! -d "$FRAPPE_DOCKER_DIR" ]]; then
  echo "Cloning frappe_docker..."
  git clone https://github.com/frappe/frappe_docker "$FRAPPE_DOCKER_DIR"
else
  echo "frappe_docker already present at $FRAPPE_DOCKER_DIR"
fi

# ── apps.json ─────────────────────────────────────────────────────────────────

if [[ ! -f "$SCRIPT_DIR/apps.json" ]]; then
  echo "Copying apps.json.example → apps.json (edit before running build.sh)"
  cp "$SCRIPT_DIR/apps.json.example" "$SCRIPT_DIR/apps.json"
else
  echo "apps.json already exists, skipping."
fi

# ── Prompts ───────────────────────────────────────────────────────────────────

prompt() {
  local label="$1" default="$2"
  read -rp "  $label [$default]: " input
  echo "${input:-$default}"
}

echo ""
echo "=== Configure your ERPNext instance ==="
echo ""

# Instance name: accept as first arg or prompt
if [[ $# -ge 1 ]]; then
  INSTANCE="$1"
  echo "  Instance name: $INSTANCE"
else
  INSTANCE=$(prompt "Instance name (used for project name and file names)" "erpnext")
fi

ERPNEXT_VERSION=$(prompt "ERPNext version (v prefix required, e.g. v16.14.0)"                              "v16.14.0")
CUSTOM_IMAGE=$(prompt    "Custom image name (e.g. localhost/myimage, registry.example.com/myimage)"    "localhost/${INSTANCE}")
CUSTOM_TAG=$(prompt      "Image tag (e.g. 16.0.0)"                                                     "16.0.0")

DB_PASSWORD_INPUT=$(prompt "DB root password (leave blank to auto-generate)" "")
if [[ -z "$DB_PASSWORD_INPUT" ]]; then
  DB_PASSWORD=$(openssl rand -base64 16 | tr -d '=/+' | head -c 24)
  echo "  → Generated DB_PASSWORD: $DB_PASSWORD"
else
  DB_PASSWORD="$DB_PASSWORD_INPUT"
fi

NGINX_PROXY_HOSTS=$(prompt "Domain(s) — comma-separated, no spaces (e.g. erp.example.com,crm.example.com)" "erp.example.com")
HTTP_PUBLISH_PORT=$(prompt "HTTP publish port"                                                              "80")

echo ""
echo "Advanced settings (FRAPPE_SITE_NAME_HEADER, CLIENT_MAX_BODY_SIZE, etc.)"
echo "can be edited directly in ${INSTANCE}.env before the compose file is generated."
echo ""

# ── Write env file ────────────────────────────────────────────────────────────

ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

if [[ -f "$ENV_FILE" ]]; then
  cp "$ENV_FILE" "${ENV_FILE}.bak"
  echo "Existing ${INSTANCE}.env backed up to ${INSTANCE}.env.bak"
fi

cp "$FRAPPE_DOCKER_DIR/example.env" "$ENV_FILE"

sed -i "s|ERPNEXT_VERSION=.*|ERPNEXT_VERSION=${ERPNEXT_VERSION}|" "$ENV_FILE"
sed -i "s|DB_PASSWORD=123|DB_PASSWORD=${DB_PASSWORD}|"             "$ENV_FILE"

{
  echo ""
  echo "NGINX_PROXY_HOSTS=${NGINX_PROXY_HOSTS}"
  echo "HTTP_PUBLISH_PORT=${HTTP_PUBLISH_PORT}"
  echo "CUSTOM_IMAGE=${CUSTOM_IMAGE}"
  echo "CUSTOM_TAG=${CUSTOM_TAG}"
} >> "$ENV_FILE"

echo "Written: ${INSTANCE}.env"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo "  Review and edit ${INSTANCE}.env if needed."
echo "  Press Enter when ready to generate the compose file."
echo "────────────────────────────────────────────────────────────────"
read -r

# ── Generate compose file ─────────────────────────────────────────────────────

echo "Generating ${INSTANCE}.yaml with the following overrides:"
echo ""
echo "  ✓ compose.mariadb.yaml    — MariaDB database service"
echo "  ✓ compose.redis.yaml      — Redis cache + queue services"
echo "  ✓ compose.nginxproxy.yaml — nginx-proxy reverse proxy (no SSL)"
echo ""
echo "Other available overrides in frappe_docker/overrides/:"
ls "$FRAPPE_DOCKER_DIR/overrides/" | sed 's/^/    /'
echo ""
echo "To use different overrides, regenerate ${INSTANCE}.yaml manually:"
echo "  docker compose --env-file ${INSTANCE}.env \\"
echo "    -f ../frappe_docker/compose.yaml \\"
echo "    -f ../frappe_docker/overrides/compose.<...>.yaml \\"
echo "    config > ${INSTANCE}.yaml"
echo ""
echo "  See: https://github.com/frappe/frappe_docker/tree/main/docs"
echo ""

docker compose \
  --env-file "$ENV_FILE" \
  -f "$FRAPPE_DOCKER_DIR/compose.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.mariadb.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.redis.yaml" \
  -f "$FRAPPE_DOCKER_DIR/overrides/compose.nginxproxy.yaml" \
  config > "$SCRIPT_DIR/${INSTANCE}.yaml"

echo "Written: ${INSTANCE}.yaml"

# ── Next steps ────────────────────────────────────────────────────────────────

echo ""
echo "=== Initialization complete ==="
echo ""
echo "  1. Edit apps.json if you need custom apps"
echo "  2. ./build.sh ${INSTANCE}    — build the custom Docker image"
echo "  3. ./up.sh ${INSTANCE}        — start all services"
echo ""
