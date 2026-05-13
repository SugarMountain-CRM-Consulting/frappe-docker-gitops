#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 <instance> <on|off> [site...]"
  echo ""
  echo "  <instance>  Instance name (e.g. ckm)"
  echo "  <on|off>    Enable or disable the scheduler"
  echo "  [site...]   One or more site names; defaults to all sites in NGINX_PROXY_HOSTS"
  echo ""
  echo "Examples:"
  echo "  $0 ckm on"
  echo "  $0 ckm off nebelspalter.sugarmountain.ch"
  exit 1
}

if [[ $# -lt 2 ]]; then
  usage
fi

INSTANCE="$1"
ACTION="$2"
shift 2

COMPOSE_FILE="$SCRIPT_DIR/${INSTANCE}.yaml"
ENV_FILE="$SCRIPT_DIR/${INSTANCE}.env"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Error: ${INSTANCE}.yaml not found." >&2
  exit 1
fi

if [[ "$ACTION" != "on" && "$ACTION" != "off" ]]; then
  echo "Error: action must be 'on' or 'off'." >&2
  usage
fi

# Resolve site list
if [[ $# -gt 0 ]]; then
  SITES=("$@")
else
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: ${INSTANCE}.env not found — provide site name(s) explicitly." >&2
    exit 1
  fi
  NGINX_PROXY_HOSTS=$(grep '^NGINX_PROXY_HOSTS=' "$ENV_FILE" | cut -d= -f2- | tr -d '\r')
  if [[ -z "$NGINX_PROXY_HOSTS" ]]; then
    echo "Error: NGINX_PROXY_HOSTS not set in ${INSTANCE}.env." >&2
    exit 1
  fi
  IFS=',' read -ra SITES <<< "$NGINX_PROXY_HOSTS"
fi

BENCH_CMD="enable-scheduler"
[[ "$ACTION" == "off" ]] && BENCH_CMD="disable-scheduler"

for SITE in "${SITES[@]}"; do
  SITE="${SITE// /}"
  echo "  bench --site $SITE $BENCH_CMD"
  docker compose -f "$COMPOSE_FILE" exec -T backend \
    bench --site "$SITE" "$BENCH_CMD"
done

echo ""
echo "Restarting scheduler..."
docker compose -f "$COMPOSE_FILE" restart scheduler

echo "Done."
