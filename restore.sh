#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <instance> <site-name> <host-database-backup-file>"
  echo ""
  echo "  <instance>               Instance name (e.g. erpnext, staging)"
  echo "  <site-name>              The Frappe site name (e.g. mysite.example.com)"
  echo "  <host-database-backup-file>  Path to the *-database.sql.gz file on the host"
  echo "                           (e.g. ./backups/20240101_120000/20240101_sitename-database.sql.gz)"
  echo ""
  echo "  Companion *-files.tar and *-private-files.tar in the same folder are"
  echo "  included automatically if present."
  exit 1
fi

INSTANCE="$1"
SITE="$2"
DB_FILE="$3"
COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"

if [[ ! -f "$DB_FILE" ]]; then
  echo "Error: file not found: $DB_FILE" >&2
  exit 1
fi

BACKUP_HOST_DIR="$(dirname "$DB_FILE")"
DB_FILENAME="$(basename "$DB_FILE")"
BASE="${DB_FILENAME%-database.sql.gz}"

PUBLIC_FILE="$BACKUP_HOST_DIR/${BASE}-files.tar"
PRIVATE_FILE="$BACKUP_HOST_DIR/${BASE}-private-files.tar"

CONTAINER=$(docker compose -f "$COMPOSE_FILE" ps -q backend)
CONTAINER_BACKUP_DIR="/home/frappe/frappe-bench/sites/$SITE/private/backups"

docker exec "$CONTAINER" mkdir -p "$CONTAINER_BACKUP_DIR"

# Copy database file
docker cp "$DB_FILE" "$CONTAINER:$CONTAINER_BACKUP_DIR/$DB_FILENAME"
FILES_TO_CLEAN=("$CONTAINER_BACKUP_DIR/$DB_FILENAME")

# Build restore command
RESTORE_CMD="bench --site $SITE restore $CONTAINER_BACKUP_DIR/$DB_FILENAME"

if [[ -f "$PUBLIC_FILE" ]]; then
  docker cp "$PUBLIC_FILE" "$CONTAINER:$CONTAINER_BACKUP_DIR/${BASE}-files.tar"
  RESTORE_CMD+=" --with-public-files $CONTAINER_BACKUP_DIR/${BASE}-files.tar"
  FILES_TO_CLEAN+=("$CONTAINER_BACKUP_DIR/${BASE}-files.tar")
  echo "Including public files: ${BASE}-files.tar"
fi

if [[ -f "$PRIVATE_FILE" ]]; then
  docker cp "$PRIVATE_FILE" "$CONTAINER:$CONTAINER_BACKUP_DIR/${BASE}-private-files.tar"
  RESTORE_CMD+=" --with-private-files $CONTAINER_BACKUP_DIR/${BASE}-private-files.tar"
  FILES_TO_CLEAN+=("$CONTAINER_BACKUP_DIR/${BASE}-private-files.tar")
  echo "Including private files: ${BASE}-private-files.tar"
fi

# Restore
docker compose -f "$COMPOSE_FILE" exec backend bash -c "$RESTORE_CMD"

# Clean up from container
docker exec "$CONTAINER" rm -f "${FILES_TO_CLEAN[@]}"

echo ""
echo "Restore complete for site: $SITE"
