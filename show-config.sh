#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"
COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: ${INSTANCE}.yaml not found." >&2
  exit 1
fi

BENCH_SITES="/home/frappe/frappe-bench/sites"

echo "=== common_site_config.json ==="
docker compose -f "$COMPOSE_FILE" exec -T backend \
  python3 -m json.tool "$BENCH_SITES/common_site_config.json" 2>/dev/null \
  || echo "  (not found)"

SITES=$(docker compose -f "$COMPOSE_FILE" exec -T backend \
  bash -c "for d in ${BENCH_SITES}/*/; do [ -f \"\${d}site_config.json\" ] && basename \"\$d\"; done" \
  | tr -d '\r')

for SITE in $SITES; do
  echo ""
  echo "=== $SITE/site_config.json ==="
  docker compose -f "$COMPOSE_FILE" exec -T backend \
    python3 -m json.tool "$BENCH_SITES/$SITE/site_config.json"
done
