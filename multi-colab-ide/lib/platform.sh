#!/usr/bin/env bash
# Platform helpers (Linux, macOS, WSL).

is_wsl() {
  if [[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSLENV:-}" ]]; then
    return 0
  fi
  grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

has_display() {
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

gcloud_browser_flag() {
  # In WSL without a GUI display, use copy-paste browser flow on Windows host.
  if is_wsl && ! has_display; then
    echo "--no-launch-browser"
  fi
}

shell_rc_files() {
  local files=()
  [[ -f "${HOME}/.bashrc" ]] && files+=("${HOME}/.bashrc")
  [[ -f "${HOME}/.zshrc" ]] && files+=("${HOME}/.zshrc")
  printf '%s\n' "${files[@]}"
}
