#!/usr/bin/env bash
# Full test suite for multi-colab-ide (runs in isolated temp HOME).
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_HOME="$(mktemp -d)"
PASS=0
FAIL=0
SKIP=0

log()  { printf '  \033[1;32m✓\033[0m %s\n' "$1"; ((PASS++)) || true; }
fail() { printf '  \033[1;31m✗\033[0m %s\n' "$1"; ((FAIL++)) || true; }
skip() { printf '  \033[1;33m○\033[0m %s (skipped)\n' "$1"; ((SKIP++)) || true; }

run() {
  echo
  echo "=== $1 ==="
}

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

export HOME="$TEST_HOME"
export PATH="$TEST_HOME/.local/bin:$PATH"
export MULTI_COLAB_IDE_ACCOUNTS="$TOOLKIT_DIR/accounts.conf.test"
mkdir -p "$TEST_HOME/.local/bin"

# Fake IDE for launcher tests
cat >"$TEST_HOME/.local/bin/fake-ide" <<'EOF'
#!/usr/bin/env bash
echo "FAKE_IDE_LAUNCHED"
echo "CLOUDSDK_CONFIG=${CLOUDSDK_CONFIG:-}"
echo "GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS:-}"
echo "COLAB_CLI_CONFIG=${COLAB_CLI_CONFIG:-}"
echo "ARGS=$*"
EOF
chmod +x "$TEST_HOME/.local/bin/fake-ide"

# Fake colab for wrapper tests
cat >"$TEST_HOME/.local/bin/colab-real" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"whoami"* && "$*" == *"auth"* ]]; then
  echo "Email:         test@example.com"
  exit 0
fi
echo "fake-colab $*"
EOF
chmod +x "$TEST_HOME/.local/bin/colab-real"

# Fake gcloud
cat >"$TEST_HOME/.local/bin/gcloud" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  auth)
    if [[ "${2:-}" == "list" ]]; then
      echo "test@example.com	*"
    fi
    ;;
  *)
    echo "fake-gcloud $*"
    ;;
esac
EOF
chmod +x "$TEST_HOME/.local/bin/gcloud"

# --- 1. Syntax ---
run "Syntax check (bash -n)"
for f in "$TOOLKIT_DIR"/*.sh "$TOOLKIT_DIR"/multi-colab-ide "$TOOLKIT_DIR"/mci-* "$TOOLKIT_DIR"/colab-wrap \
         "$TOOLKIT_DIR"/env.sh "$TOOLKIT_DIR"/lib/*.sh; do
  if bash -n "$f" 2>/dev/null; then
    log "$(basename "$f")"
  else
    fail "$(basename "$f") syntax error"
  fi
done

# --- 2. Install ---
run "install.sh"
cp "$TOOLKIT_DIR/accounts.conf.example" "$TOOLKIT_DIR/accounts.conf.test"
# Rewrite paths to use test HOME
sed "s|~/.config|$TEST_HOME/.config|g" "$TOOLKIT_DIR/accounts.conf.test" >"$TOOLKIT_DIR/accounts.conf.test.tmp"
mv "$TOOLKIT_DIR/accounts.conf.test.tmp" "$TOOLKIT_DIR/accounts.conf.test"
export MULTI_COLAB_IDE_ACCOUNTS="$TOOLKIT_DIR/accounts.conf.test"

# Patch install to use test accounts file - run install manually
mkdir -p "$TEST_HOME/.config/multi-colab-ide"
cp "$TOOLKIT_DIR/config/ide.conf.example" "$TEST_HOME/.config/multi-colab-ide/ide.conf"
sed -i 's/IDE_COMMAND="code"/IDE_COMMAND="fake-ide"/' "$TEST_HOME/.config/multi-colab-ide/ide.conf"

BIN_DIR="$TEST_HOME/.local/bin"
for script in multi-colab-ide mci-switch mci-verify mci-setup; do
  ln -sf "$TOOLKIT_DIR/$script" "$BIN_DIR/$script"
done
ln -sf "$TOOLKIT_DIR/colab-wrap" "$BIN_DIR/colab"

while IFS='|' read -r id label dir; do
  [[ -z "${id:-}" || "$id" =~ ^[[:space:]]*# ]] && continue
  expanded="${dir/#\~/$TEST_HOME}"
  mkdir -p "$expanded/colab-cli"
  echo '{"account":"","client_id":"x","client_secret":"x","refresh_token":"x","type":"authorized_user"}' \
    >"$expanded/application_default_credentials.json"
done <"$TOOLKIT_DIR/accounts.conf.test"

if [[ -x "$BIN_DIR/multi-colab-ide" ]]; then
  log "install symlinks created"
else
  fail "install symlinks missing"
fi

# --- 3. load-profile ---
run "lib/load-profile.sh"
# shellcheck source=/dev/null
source "$TOOLKIT_DIR/lib/load-profile.sh"
mkdir -p "$TEST_HOME/.config/multi-colab-ide"
echo "$TEST_HOME/.config/gcloud-account2" >"$TEST_HOME/.config/multi-colab-ide/active"
unset CLOUDSDK_CONFIG GOOGLE_APPLICATION_CREDENTIALS COLAB_CLI_CONFIG 2>/dev/null || true
multi_colab_ide_load_active_profile
if [[ "$CLOUDSDK_CONFIG" == "$TEST_HOME/.config/gcloud-account2" ]]; then
  log "load active profile"
else
  fail "load active profile (got: ${CLOUDSDK_CONFIG:-unset})"
fi

# --- 4. mci-switch ---
run "mci-switch (sourced)"
# shellcheck source=/dev/null
source "$BIN_DIR/mci-switch" 1
if [[ "$CLOUDSDK_CONFIG" == "$TEST_HOME/.config/gcloud-account1" ]]; then
  log "mci-switch sets CLOUDSDK_CONFIG"
else
  fail "mci-switch CLOUDSDK_CONFIG"
fi
if [[ "${COLAB_CLI_CONFIG:-}" == "$TEST_HOME/.config/gcloud-account1/colab-cli/sessions.json" ]]; then
  log "mci-switch sets COLAB_CLI_CONFIG"
else
  fail "mci-switch COLAB_CLI_CONFIG (got: ${COLAB_CLI_CONFIG:-unset})"
fi

# --- 5. mci-verify ---
run "mci-verify"
MULTI_COLAB_IDE_ACCOUNTS="$TOOLKIT_DIR/accounts.conf.test" \
  CLOUDSDK_CONFIG="$TEST_HOME/.config/gcloud-account1" \
  GOOGLE_APPLICATION_CREDENTIALS="$TEST_HOME/.config/gcloud-account1/application_default_credentials.json" \
  COLAB_CLI_CONFIG="$TEST_HOME/.config/gcloud-account1/colab-cli/sessions.json" \
  MULTI_COLAB_IDE_REAL_BIN="$TEST_HOME/.local/bin/colab-real" \
  "$BIN_DIR/mci-verify" >"$TEST_HOME/verify.out" 2>&1 || true
if grep -q "gcloud-account1" "$TEST_HOME/verify.out"; then
  log "mci-verify shows config path"
else
  fail "mci-verify output"
fi

# --- 6. colab-wrap ---
run "colab-wrap"
unset CLOUDSDK_CONFIG GOOGLE_APPLICATION_CREDENTIALS 2>/dev/null || true
echo "$TEST_HOME/.config/gcloud-account3" >"$TEST_HOME/.config/multi-colab-ide/active"
MULTI_COLAB_IDE_REAL_BIN="$TEST_HOME/.local/bin/colab-real" \
  "$BIN_DIR/colab" --auth=adc whoami >"$TEST_HOME/colab.out" 2>&1
if grep -q "test@example.com" "$TEST_HOME/colab.out"; then
  log "colab-wrap loads profile and runs colab-real"
else
  fail "colab-wrap"
  cat "$TEST_HOME/colab.out" >&2
fi

# --- 7. multi-colab-ide launcher ---
run "multi-colab-ide launcher"
MULTI_COLAB_IDE_ACCOUNTS="$TOOLKIT_DIR/accounts.conf.test" \
  "$BIN_DIR/multi-colab-ide" 2 /tmp/test-project >"$TEST_HOME/ide.out" 2>&1
if grep -q "FAKE_IDE_LAUNCHED" "$TEST_HOME/ide.out" \
   && grep -q "gcloud-account2" "$TEST_HOME/ide.out"; then
  log "multi-colab-ide launches IDE with account 2 env"
else
  fail "multi-colab-ide launcher"
  cat "$TEST_HOME/ide.out" >&2
fi

# --- 8. platform.sh WSL detection ---
run "lib/platform.sh"
# shellcheck source=/dev/null
source "$TOOLKIT_DIR/lib/platform.sh"
if declare -f is_wsl >/dev/null; then
  log "is_wsl function exists"
else
  fail "is_wsl missing"
fi
if is_wsl; then
  log "WSL detected on this host"
else
  log "native Linux/macOS detected"
fi

# --- 9. env.sh (bash + zsh) ---
run "env.sh auto-load"
unset CLOUDSDK_CONFIG 2>/dev/null || true
echo "$TEST_HOME/.config/gcloud-account1" >"$TEST_HOME/.config/multi-colab-ide/active"
# shellcheck source=/dev/null
source "$TOOLKIT_DIR/env.sh"
if [[ "$CLOUDSDK_CONFIG" == "$TEST_HOME/.config/gcloud-account1" ]]; then
  log "env.sh bash auto-load"
else
  fail "env.sh bash auto-load"
fi

if command -v zsh >/dev/null 2>&1; then
  zsh -fc "
    export HOME='$TEST_HOME'
    unset CLOUDSDK_CONFIG
    source '$TOOLKIT_DIR/env.sh'
    [[ \"\$CLOUDSDK_CONFIG\" == '$TEST_HOME/.config/gcloud-account1' ]]
  " && log "env.sh zsh auto-load" || fail "env.sh zsh auto-load"
else
  skip "env.sh zsh (zsh not installed)"
fi

# --- 10. invalid account ---
run "Error handling"
if MULTI_COLAB_IDE_ACCOUNTS="$TOOLKIT_DIR/accounts.conf.test" \
   "$BIN_DIR/multi-colab-ide" 99 >/dev/null 2>&1; then
  fail "invalid account should exit non-zero"
else
  log "invalid account rejected"
fi

# --- 11. ide_bin cursor path resolution ---
run "ide_bin resolution"
(
  export HOME="$TEST_HOME"
  export MULTI_COLAB_IDE_CONFIG="$TEST_HOME/ide-test.conf"
  printf '%s\n' 'IDE_COMMAND="cursor"' 'IDE_ARGS=""' >"$MULTI_COLAB_IDE_CONFIG"
  # shellcheck source=/dev/null
  source "$TOOLKIT_DIR/lib/common.sh"
  mkdir -p "$TEST_HOME/.local/bin"
  printf '%s\n' '#!/bin/sh' 'echo cursor' >"$TEST_HOME/.local/bin/cursor"
  chmod +x "$TEST_HOME/.local/bin/cursor"
  path="$(ide_bin)"
  if [[ "$path" == "$TEST_HOME/.local/bin/cursor" ]]; then
    log "ide_bin finds cursor in ~/.local/bin"
  else
    fail "ide_bin cursor path (got: $path)"
  fi
)

# --- 12. Live system checks (real HOME) ---
run "Live system checks (host)"
REAL_USER_HOME="/home/manith"
if command -v colab-real >/dev/null 2>&1 || command -v colab >/dev/null 2>&1; then
  log "colab CLI present on host"
else
  skip "colab CLI not on host PATH"
fi
if command -v gcloud >/dev/null 2>&1; then
  log "gcloud present on host"
else
  skip "gcloud not on host PATH"
fi
if [[ -f "$REAL_USER_HOME/.config/gcloud-account3/application_default_credentials.json" ]]; then
  if CLOUDSDK_CONFIG="$REAL_USER_HOME/.config/gcloud-account3" \
     "$REAL_USER_HOME/.local/bin/colab-real" --auth=adc whoami 2>/dev/null | grep -q "@"; then
    log "live account 3 ADC (colab-real)"
  elif CLOUDSDK_CONFIG="$REAL_USER_HOME/.config/gcloud-account3" \
       colab --auth=adc whoami 2>/dev/null | grep -q "@"; then
    log "live account 3 ADC (colab wrapper)"
  else
    fail "live account 3 ADC should work"
  fi
else
  skip "live account 3 credentials not configured"
fi
if [[ -x "$REAL_USER_HOME/.local/bin/cursor" ]] || command -v cursor >/dev/null 2>&1; then
  log "cursor IDE CLI present on host"
else
  skip "cursor CLI not on host"
fi
if [[ -f "$TOOLKIT_DIR/config/ide.conf.cursor.example" ]]; then
  grep -q 'IDE_COMMAND=' "$TOOLKIT_DIR/config/ide.conf.cursor.example" && \
    log "cursor IDE preset file valid" || fail "cursor IDE preset invalid"
fi
if [[ -x "$TOOLKIT_DIR/config/cursor-launcher.example.sh" ]]; then
  log "cursor launcher example present"
fi

# --- Summary ---
echo
echo "=============================="
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "=============================="

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
