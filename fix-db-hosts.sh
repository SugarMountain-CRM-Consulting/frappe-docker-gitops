#!/usr/bin/env bash
set -euo pipefail

# Frappe binds MariaDB users to the container IP at site creation time.
# When containers restart, Docker may reassign IPs, causing authentication
# failures. This script updates all site DB users to allow connections from
# any host ('%'), which is safe since MariaDB is not exposed outside Docker.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"
COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: ${INSTANCE}.env not found." >&2
  exit 1
fi

DB_PASSWORD=$(grep '^DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)

echo "Fixing MariaDB user hosts for instance: $INSTANCE"

docker compose -f "$COMPOSE_FILE" exec -T db \
  mysql -uroot -p"$DB_PASSWORD" -e \
  "UPDATE mysql.user SET Host='%' WHERE Host NOT IN ('localhost','127.0.0.1','%') AND User NOT IN ('root','mariadb.sys'); FLUSH PRIVILEGES;"

echo "Done. Sites should now survive container restarts."
