#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"

docker compose -f "$SCRIPT_DIR/${INSTANCE}.yaml" up -d
