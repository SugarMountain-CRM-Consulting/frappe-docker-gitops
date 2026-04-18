#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"
VOLUMES=""

for arg in "$@"; do
  [[ "$arg" == "-v" ]] && VOLUMES="-v"
done

if [[ -n "$VOLUMES" ]]; then
  echo "Stopping $INSTANCE and removing volumes..."
else
  echo "Stopping $INSTANCE (data volumes preserved)..."
fi

docker compose -f "$SCRIPT_DIR/${INSTANCE}.yaml" down $VOLUMES
