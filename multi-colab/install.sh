#!/usr/bin/env bash
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"

install -d "$BIN_DIR"
install -d "$HOME/.config/multi-colab"

for script in multi-colab account-switch verify setup-account; do
  ln -sf "$TOOLKIT_DIR/$script" "$BIN_DIR/$script"
done

if [[ ! -f "$TOOLKIT_DIR/accounts.conf" ]]; then
  cp "$TOOLKIT_DIR/accounts.conf.example" "$TOOLKIT_DIR/accounts.conf"
  echo "Created $TOOLKIT_DIR/accounts.conf from example."
fi

# Create isolated gcloud config directories.
while IFS='|' read -r id label dir; do
  [[ -z "${id:-}" || "$id" =~ ^[[:space:]]*# ]] && continue
  expanded="${dir/#\~/$HOME}"
  mkdir -p "$expanded/colab-cli"
done <"$TOOLKIT_DIR/accounts.conf"

cat <<EOF

multi-colab installed.

Commands (in PATH via $BIN_DIR):
  multi-colab           Launch Cursor with account menu
  account-switch        Switch account in current shell
  verify                Show active Google/Colab credentials
  setup-account <id>    First-time auth for one profile

First-time setup (repeat per account):
  setup-account 1
  setup-account 2
  setup-account 3

Edit account labels:
  $TOOLKIT_DIR/accounts.conf

Daily use:
  multi-colab

EOF

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Note: add $BIN_DIR to your PATH if needed."
fi
