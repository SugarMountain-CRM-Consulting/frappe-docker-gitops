#!/usr/bin/env bash
set -euo pipefail

# Resynchronises sites/assets/assets.json with the hashed filenames that are
# actually present in the running image.
#
# When is this needed?
#   After deploying a newly built image the persistent sites/ volume still holds
#   the old assets.json (with old content hashes). The new image has fresh hashed
#   files, so the hashes in assets.json no longer match the files on disk, causing
#   the browser to receive 404s for CSS/JS assets.
#
# What does it do?
#   Runs `bench build --using-cached` inside the backend container. This rescans
#   the compiled dist files and rewrites assets.json to reference the correct
#   hashes — without recompiling anything (takes a few seconds).
#
# Usage:
#   ./sync-assets.sh [instance]   (default: erpnext)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTANCE="${1:-erpnext}"

echo "Syncing asset hashes for '$INSTANCE'..."
docker compose -f "$SCRIPT_DIR/${INSTANCE}.yaml" \
  exec backend bench build --using-cached

echo "Done. Reload the browser to verify assets load correctly."
