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

NGINX_PROXY_HOSTS=$(grep '^NGINX_PROXY_HOSTS=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')

if [[ -z "$NGINX_PROXY_HOSTS" ]]; then
  echo "Error: NGINX_PROXY_HOSTS is not set in ${INSTANCE}.env." >&2
  exit 1
fi

read -rsp "MariaDB root password: " DB_PASSWORD
echo ""
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
      test -f "/home/frappe/frappe-bench/sites/${SITE}/site_config.json" 2>/dev/null; then
    echo "  Site already exists — skipping creation."
  else
    echo "  Running: bench new-site $SITE --db-root-password *** --admin-password *** --no-mariadb-socket"
    docker compose -f "$COMPOSE_FILE" exec -T backend \
      bench new-site "$SITE" \
        --db-root-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --no-mariadb-socket
    echo "  Site created."
    DB_USER=$(docker compose -f "$COMPOSE_FILE" exec -T backend \
      python3 -c "import json; print(json.load(open('/home/frappe/frappe-bench/sites/${SITE}/site_config.json'))['db_name'])" \
      | tr -d '\r')
    echo "  Fixing DB host for user '$DB_USER'..."
    docker compose -f "$COMPOSE_FILE" exec -T -e MYSQL_PWD="$DB_PASSWORD" db \
      mariadb -uroot --verbose -e \
      "UPDATE mysql.global_priv SET Host='%' WHERE User='${DB_USER}' AND Host != '%'; FLUSH PRIVILEGES; SELECT User, Host FROM mysql.global_priv WHERE User='${DB_USER}';"
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
    echo "  Running: bench --site $SITE install-app $APP"
    docker compose -f "$COMPOSE_FILE" exec -T backend \
      bench --site "$SITE" install-app "$APP"
  done
done

echo ""
echo "Done."
