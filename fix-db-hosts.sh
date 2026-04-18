#!/usr/bin/env bash
set -euo pipefail

# Frappe binds MariaDB users to the container IP at site creation time.
# When containers restart, Docker may reassign IPs, causing authentication
# failures. This script updates all site DB users to allow connections from
# any host ('%'), which is safe since MariaDB is not exposed outside Docker.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"
COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: ${INSTANCE}.yaml not found." >&2
  exit 1
fi

echo "For each site this will run as MariaDB root:"
echo ""
echo "  UPDATE mysql.global_priv SET Host='%'"
echo "    WHERE User='<site_db_user>' AND Host != '%';"
echo "  FLUSH PRIVILEGES;"
echo ""
echo "Press Ctrl+C to cancel."
echo ""
read -rsp "MariaDB root password: " DB_PASSWORD
echo ""

echo "Fixing MariaDB user hosts for instance: $INSTANCE"

SITES=$(docker compose -f "$COMPOSE_FILE" exec -T backend \
  bash -c "for d in /home/frappe/frappe-bench/sites/*/; do [ -f \"\${d}site_config.json\" ] && basename \"\$d\"; done" \
  | tr -d '\r')

if [[ -z "$SITES" ]]; then
  echo "No sites found." >&2
  exit 1
fi

for SITE in $SITES; do
  echo ""
  echo "  Site: $SITE"
  DB_USER=$(docker compose -f "$COMPOSE_FILE" exec -T backend \
    python3 -c "import json; print(json.load(open('/home/frappe/frappe-bench/sites/${SITE}/site_config.json'))['db_name'])" \
    | tr -d '\r')
  echo "  DB user: $DB_USER"
  docker compose -f "$COMPOSE_FILE" exec -T -e MYSQL_PWD="$DB_PASSWORD" db \
    mariadb -uroot --verbose -e \
    "UPDATE mysql.global_priv SET Host='%' WHERE User='${DB_USER}' AND Host != '%'; FLUSH PRIVILEGES; SELECT User, Host FROM mysql.global_priv WHERE User='${DB_USER}';"
done

echo ""
echo "Done. Sites should now survive container restarts."
