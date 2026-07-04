#!/usr/bin/env bash
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
STATE_DIR="${HOME}/.config/multi-colab-ide"
ENV_MARKER="# multi-colab-ide env"
ENV_LINE="[[ -f \"$TOOLKIT_DIR/env.sh\" ]] && source \"$TOOLKIT_DIR/env.sh\""

install -d "$BIN_DIR"
install -d "$STATE_DIR"

for script in multi-colab-ide mci-switch mci-verify mci-setup; do
  chmod +x "$TOOLKIT_DIR/$script"
  ln -sf "$TOOLKIT_DIR/$script" "$BIN_DIR/$script"
done
chmod +x "$TOOLKIT_DIR/colab-wrap"

# Wrap colab so it auto-loads the active profile in any shell.
if [[ -x "$BIN_DIR/colab" && ! -e "$BIN_DIR/colab-real" ]]; then
  mv "$BIN_DIR/colab" "$BIN_DIR/colab-real"
  echo "Renamed colab -> colab-real"
elif [[ ! -e "$BIN_DIR/colab-real" ]]; then
  real_colab="$(command -v colab 2>/dev/null || true)"
  if [[ -n "$real_colab" && "$real_colab" != "$BIN_DIR/colab" ]]; then
    ln -sf "$real_colab" "$BIN_DIR/colab-real"
    echo "Linked colab-real -> $real_colab"
  fi
fi
ln -sf "$TOOLKIT_DIR/colab-wrap" "$BIN_DIR/colab"

if [[ ! -f "$TOOLKIT_DIR/accounts.conf" ]]; then
  cp "$TOOLKIT_DIR/accounts.conf.example" "$TOOLKIT_DIR/accounts.conf"
  echo "Created $TOOLKIT_DIR/accounts.conf from example."
fi

if [[ ! -f "$STATE_DIR/ide.conf" ]]; then
  cp "$TOOLKIT_DIR/config/ide.conf.example" "$STATE_DIR/ide.conf"
  echo "Created $STATE_DIR/ide.conf from example."
fi

while IFS='|' read -r id label dir; do
  [[ -z "${id:-}" || "$id" =~ ^[[:space:]]*# ]] && continue
  expanded="${dir/#\~/$HOME}"
  mkdir -p "$expanded/colab-cli"
done <"$TOOLKIT_DIR/accounts.conf"

hook_shell_rc() {
  local rc_file="$1"
  if [[ ! -f "$rc_file" ]]; then
    return 0
  fi
  if grep -qF "$ENV_MARKER" "$rc_file" 2>/dev/null; then
    echo "Shell hook already present in $rc_file"
    return 0
  fi
  cat >>"$rc_file" <<EOF

$ENV_MARKER
$ENV_LINE
EOF
  echo "Added shell hook to $rc_file"
}

hook_shell_rc "${HOME}/.bashrc"
hook_shell_rc "${HOME}/.zshrc"

platform_note=""
if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  platform_note="
WSL detected:
  Use 'mci-setup <id> --no-launch-browser' if the browser does not open.
  Open the printed URL in your Windows browser."
fi

cat <<EOF

multi-colab-ide installed.

Commands (in PATH via $BIN_DIR):
  multi-colab-ide     Launch IDE with account menu
  mci-switch          Switch account in current shell
  mci-verify          Show active Google/Colab credentials
  mci-setup <id>      First-time auth for one profile

Configure your IDE:
  $STATE_DIR/ide.conf
  Cursor preset:
    cp $TOOLKIT_DIR/config/cursor-launcher.example.sh ~/.local/bin/cursor
    chmod +x ~/.local/bin/cursor   # then edit the AppImage path
    cp $TOOLKIT_DIR/config/ide.conf.cursor.example $STATE_DIR/ide.conf

First-time setup (repeat per account):
  mci-setup 1
  mci-setup 2
  mci-setup 3

Edit account labels:
  $TOOLKIT_DIR/accounts.conf

Daily use:
  multi-colab-ide
$platform_note

EOF

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Note: add $BIN_DIR to your PATH if needed."
fi
