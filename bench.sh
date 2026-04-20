#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"
COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: ${INSTANCE}.yaml not found." >&2
  exit 1
fi

exec docker compose -f "$COMPOSE_FILE" exec \
  -w /home/frappe/frappe-bench backend bash
