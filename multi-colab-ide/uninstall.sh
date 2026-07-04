#!/usr/bin/env bash
set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
ENV_MARKER="# multi-colab-ide env"

remove_shell_hook() {
  local rc_file="$1"
  [[ -f "$rc_file" ]] || return 0
  if grep -qF "$ENV_MARKER" "$rc_file" 2>/dev/null; then
    sed -i "/$ENV_MARKER/,+1d" "$rc_file"
    echo "Removed shell hook from $rc_file"
  fi
}

for script in multi-colab-ide mci-switch mci-verify mci-setup; do
  rm -f "$BIN_DIR/$script"
done

if [[ -L "$BIN_DIR/colab" && "$(readlink "$BIN_DIR/colab")" == "$TOOLKIT_DIR/colab-wrap" ]]; then
  rm -f "$BIN_DIR/colab"
  if [[ -e "$BIN_DIR/colab-real" ]]; then
    mv "$BIN_DIR/colab-real" "$BIN_DIR/colab"
    echo "Restored colab from colab-real"
  fi
fi

remove_shell_hook "${HOME}/.bashrc"
remove_shell_hook "${HOME}/.zshrc"

echo "multi-colab-ide uninstalled (config in ~/.config/multi-colab-ide preserved)."
