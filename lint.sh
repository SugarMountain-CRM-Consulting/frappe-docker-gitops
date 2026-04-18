#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_file()    { [[ -f "$1" ]] && pass "$2" || fail "$2"; }
assert_contains() { grep -q "$1" "$2" 2>/dev/null && pass "$3" || fail "$3"; }
assert_not_contains() { ! grep -q "$1" "$2" 2>/dev/null && pass "$3" || fail "$3"; }

# ── Syntax checks ─────────────────────────────────────────────────────────────

echo "=== Syntax checks ==="
for script in "$SCRIPT_DIR"/*.sh; do
  name="$(basename "$script")"
  if bash -n "$script" 2>/dev/null; then
    pass "$name"
  else
    fail "$name (syntax error)"
  fi
done

# ── initialize.sh smoke test ──────────────────────────────────────────────────

echo ""
echo "=== initialize.sh smoke test ==="

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Fake frappe_docker with the files initialize.sh needs
FAKE_FRAPPE="$TMPDIR_TEST/frappe_docker"
mkdir -p "$FAKE_FRAPPE/overrides"

cat > "$FAKE_FRAPPE/example.env" << 'EOF'
ERPNEXT_VERSION=v16.14.0
DB_PASSWORD=123
LETSENCRYPT_EMAIL=mail@example.com
NGINX_PROXY_HOSTS=
HTTP_PUBLISH_PORT=
FRAPPE_SITE_NAME_HEADER=
EOF

touch "$FAKE_FRAPPE/compose.yaml"
touch "$FAKE_FRAPPE/overrides/compose.mariadb.yaml"
touch "$FAKE_FRAPPE/overrides/compose.redis.yaml"
touch "$FAKE_FRAPPE/overrides/compose.nginxproxy.yaml"

# Fake bin dir — intercepts docker, git, openssl so no real calls are made
FAKE_BIN="$TMPDIR_TEST/bin"
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/git" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$FAKE_BIN/docker" << 'EOF'
#!/usr/bin/env bash
# Handle prerequisite check
if [[ "${2:-}" == "version" ]]; then echo "Docker Compose version v2.0.0"; exit 0; fi
# Handle compose config — output a minimal valid yaml
echo "name: testinstance"
echo "services:"
echo "  backend:"
echo "    image: localhost/test:1.0"
EOF

cat > "$FAKE_BIN/openssl" << 'EOF'
#!/usr/bin/env bash
echo "AAABBBCCCDDDEEEFFFGGG==="
EOF

chmod +x "$FAKE_BIN/git" "$FAKE_BIN/docker" "$FAKE_BIN/openssl"

# Fake gitops dir for the test run
FAKE_GITOPS="$TMPDIR_TEST/gitops"
mkdir -p "$FAKE_GITOPS"
cp "$SCRIPT_DIR/initialize.sh" "$FAKE_GITOPS/"
cp "$SCRIPT_DIR/apps.json.example" "$FAKE_GITOPS/"

# Pipe answers to all read prompts in initialize.sh:
#   1. instance name
#   2. ERPNext version
#   3. custom image
#   4. image tag
#   5. DB password (blank → auto-generate)
#   6. domains
#   7. HTTP port
#   8. <enter> to continue past review pause
ANSWERS=$'testinstance\nv16.14.0\nlocalhost/test\n1.0.0\n\ntest.example.com\n8080\n\n'

PATH="$FAKE_BIN:$PATH" bash "$FAKE_GITOPS/initialize.sh" \
  <<< "$ANSWERS" > /dev/null 2>&1

ENV_FILE="$FAKE_GITOPS/testinstance.env"
YAML_FILE="$FAKE_GITOPS/testinstance.yaml"

assert_file         "$ENV_FILE"                              "env file created"
assert_file         "$YAML_FILE"                             "yaml file generated"
assert_file         "$FAKE_GITOPS/apps.json"                 "apps.json copied from example"
assert_contains     "CUSTOM_IMAGE=localhost/test" "$ENV_FILE" "CUSTOM_IMAGE set"
assert_contains     "CUSTOM_TAG=1.0.0"            "$ENV_FILE" "CUSTOM_TAG set"
assert_contains     "NGINX_PROXY_HOSTS=test.example.com" "$ENV_FILE" "NGINX_PROXY_HOSTS set"
assert_contains     "HTTP_PUBLISH_PORT=8080"       "$ENV_FILE" "HTTP_PUBLISH_PORT set"
assert_contains     "ERPNEXT_VERSION=v16.14.0"     "$ENV_FILE" "ERPNEXT_VERSION set"
assert_not_contains "DB_PASSWORD=123"              "$ENV_FILE" "default DB_PASSWORD replaced"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
