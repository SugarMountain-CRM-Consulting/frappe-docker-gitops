#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <instance> <site> <app> [app...]"
  echo ""
  echo "  <instance>  Instance name (e.g. erpnext, staging)"
  echo "  <site>      Frappe site name (e.g. mysite.example.com)"
  echo "  <app>       One or more app names to install"
  exit 1
fi

INSTANCE="$1"
SITE="$2"
shift 2
APPS=("$@")

COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"

for APP in "${APPS[@]}"; do
  echo "Installing $APP on $SITE..."
  docker compose -f "$COMPOSE_FILE" exec backend \
    bench --site "$SITE" install-app "$APP"
done

echo ""
echo "Done."
