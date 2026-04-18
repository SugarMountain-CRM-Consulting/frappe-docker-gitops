#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"
COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"
BACKUP_DIR="$SCRIPT_DIR/backups/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q backend)

# Mark timestamp so we can identify files created by this backup run
docker exec "$CONTAINER" touch /tmp/backup_marker

# Run backup
docker compose -f "$COMPOSE_FILE" exec backend bench --site all backup --with-files

# Find and copy new backup files to host, then remove from container
NEW_FILES=$(docker exec "$CONTAINER" \
  find /home/frappe/frappe-bench/sites -path "*/private/backups/*" \
  -newer /tmp/backup_marker -type f)

if [[ -z "$NEW_FILES" ]]; then
  echo "Warning: no backup files found." >&2
  docker exec "$CONTAINER" rm /tmp/backup_marker
  exit 1
fi

while IFS= read -r file; do
  docker cp "$CONTAINER:$file" "$BACKUP_DIR/"
  docker exec "$CONTAINER" rm "$file"
done <<< "$NEW_FILES"

docker exec "$CONTAINER" rm /tmp/backup_marker

echo ""
echo "Backups saved to: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
