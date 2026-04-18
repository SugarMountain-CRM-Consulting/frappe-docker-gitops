#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"
COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: ${INSTANCE}.env not found. Run ./initialize.sh ${INSTANCE} first." >&2
  exit 1
fi

NGINX_PROXY_HOSTS=$(grep '^NGINX_PROXY_HOSTS=' "$ENV_FILE" | cut -d= -f2-)
DB_PASSWORD=$(grep '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)

if [[ -z "$NGINX_PROXY_HOSTS" ]]; then
  echo "Error: NGINX_PROXY_HOSTS is not set in ${INSTANCE}.env." >&2
  exit 1
fi

read -rsp "Admin password for new sites: " ADMIN_PASSWORD
echo ""

# Get list of available apps in the bench
AVAILABLE_APPS=$(docker compose -f "$COMPOSE_FILE" exec -T backend \
  bash -c "ls /home/frappe/frappe-bench/apps/" | tr -d '\r')

# Split NGINX_PROXY_HOSTS on commas
IFS=',' read -ra SITES <<< "$NGINX_PROXY_HOSTS"

for SITE in "${SITES[@]}"; do
  SITE="${SITE// /}"   # trim spaces
  echo ""
  echo "=== Site: $SITE ==="

  # Check if site already exists
  if docker compose -f "$COMPOSE_FILE" exec -T backend \
      bench --site "$SITE" version &>/dev/null 2>&1; then
    echo "  Site already exists — skipping creation."
  else
    echo "  Creating site..."
    docker compose -f "$COMPOSE_FILE" exec -T backend \
      bench new-site "$SITE" \
        --db-root-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --no-mariadb-socket
    echo "  Site created."
  fi

  # App selection
  echo ""
  echo "  Available apps:"
  echo "$AVAILABLE_APPS" | grep -v '^frappe$' | nl -w2 -s') '
  echo ""
  read -rp "  Apps to install (comma-separated names, 'all', or blank to skip): " APP_INPUT

  if [[ -z "$APP_INPUT" ]]; then
    echo "  Skipping app installation."
    continue
  fi

  if [[ "$APP_INPUT" == "all" ]]; then
    SELECTED_APPS=$(echo "$AVAILABLE_APPS" | grep -v '^frappe$' | tr '\n' ' ')
  else
    SELECTED_APPS="${APP_INPUT//,/ }"
  fi

  for APP in $SELECTED_APPS; do
    APP="${APP// /}"
    [[ -z "$APP" ]] && continue
    echo "  Installing $APP..."
    docker compose -f "$COMPOSE_FILE" exec -T backend \
      bench --site "$SITE" install-app "$APP"
  done
done

echo ""
echo "Fixing MariaDB user hosts..."
echo "  (Frappe binds DB users to the container IP at creation time — setting to '%' so"
echo "   connections survive container restarts when Docker reassigns IP addresses.)"
docker compose -f "$COMPOSE_FILE" exec -T -e MYSQL_PWD="$DB_PASSWORD" db \
  mariadb -uroot -e \
  "UPDATE mysql.user SET Host='%' WHERE Host NOT IN ('localhost','127.0.0.1','%') AND User NOT IN ('root','mariadb.sys'); FLUSH PRIVILEGES;"
echo "  Done."

echo ""
echo "Done."
