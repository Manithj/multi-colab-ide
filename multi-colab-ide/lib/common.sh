#!/usr/bin/env bash
# Shared helpers for multi-colab-ide.

_script="${BASH_SOURCE[0]}"
while [[ -L "$_script" ]]; do
  _dir="$(cd "$(dirname "$_script")" && pwd)"
  _script="$(readlink "$_script")"
  [[ "$_script" != /* ]] && _script="$_dir/$_script"
done
TOOLKIT_DIR="$(cd "$(dirname "$_script")/.." && pwd)"

STATE_DIR="${MULTI_COLAB_IDE_STATE_DIR:-$HOME/.config/multi-colab-ide}"
ACCOUNTS_FILE="${MULTI_COLAB_IDE_ACCOUNTS:-$TOOLKIT_DIR/accounts.conf}"
IDE_CONFIG="${MULTI_COLAB_IDE_CONFIG:-$STATE_DIR/ide.conf}"

COLAB_ADC_SCOPES="openid,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/colaboratory"

# shellcheck source=platform.sh
source "$TOOLKIT_DIR/lib/platform.sh"

resolve_toolkit_dir() {
  _script="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  while [[ -L "$_script" ]]; do
    _dir="$(cd "$(dirname "$_script")" && pwd)"
    _script="$(readlink "$_script")"
    [[ "$_script" != /* ]] && _script="$_dir/$_script"
  done
  cd "$(dirname "$_script")" && pwd
}

expand_path() {
  # shellcheck disable=SC2001
  echo "$1" | sed "s|^~|$HOME|"
}

load_ide_config() {
  IDE_COMMAND="${IDE_COMMAND:-code}"
  IDE_ARGS="${IDE_ARGS:-}"

  if [[ -f "$IDE_CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$IDE_CONFIG"
  elif [[ -f "$TOOLKIT_DIR/config/ide.conf.example" ]]; then
    # shellcheck disable=SC1090
    source "$TOOLKIT_DIR/config/ide.conf.example"
  fi

  if [[ -z "${IDE_COMMAND:-}" ]]; then
    IDE_COMMAND="code"
  fi
}

ide_bin() {
  load_ide_config

  # Expand ~ in IDE_COMMAND paths.
  local cmd="${IDE_COMMAND/#\~/$HOME}"

  if command -v "$cmd" >/dev/null 2>&1; then
    command -v "$cmd"
    return 0
  fi

  if [[ -x "$cmd" ]]; then
    echo "$cmd"
    return 0
  fi

  local candidate
  for candidate in \
    "$HOME/.local/bin/$cmd" \
    "/usr/bin/$cmd" \
    "/usr/local/bin/$cmd"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  # Cursor on macOS (App bundle CLI) — only when command name is literally "cursor"
  if [[ "$(basename "$cmd")" == "cursor" && -x "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" ]]; then
    echo "/Applications/Cursor.app/Contents/Resources/app/bin/cursor"
    return 0
  fi

  echo "$cmd"
}

load_accounts() {
  if [[ ! -f "$ACCOUNTS_FILE" ]]; then
    echo "Accounts file not found: $ACCOUNTS_FILE" >&2
    echo "Run: $TOOLKIT_DIR/install.sh" >&2
    return 1
  fi

  ACCOUNT_IDS=()
  ACCOUNT_LABELS=()
  ACCOUNT_DIRS=()

  local line id label dir
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    IFS='|' read -r id label dir <<<"$line"
    id="${id//[[:space:]]/}"
    label="${label#"${label%%[![:space:]]*}"}"
    label="${label%"${label##*[![:space:]]}"}"
    dir="$(expand_path "$dir")"
    [[ -z "$id" || -z "$dir" ]] && continue
    ACCOUNT_IDS+=("$id")
    ACCOUNT_LABELS+=("${label:-$dir}")
    ACCOUNT_DIRS+=("$dir")
  done <"$ACCOUNTS_FILE"
}

print_account_menu() {
  load_accounts || return 1
  echo "========================="
  echo "Select Google Account"
  echo "========================="
  echo
  local i
  for i in "${!ACCOUNT_IDS[@]}"; do
    printf "%s) %s\n" "${ACCOUNT_IDS[$i]}" "${ACCOUNT_LABELS[$i]}"
  done
  echo
}

find_account_index() {
  local choice="$1"
  local i
  for i in "${!ACCOUNT_IDS[@]}"; do
    if [[ "${ACCOUNT_IDS[$i]}" == "$choice" ]]; then
      echo "$i"
      return 0
    fi
  done
  return 1
}

persist_active_profile() {
  local config_dir="$1"
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$config_dir" >"$STATE_DIR/active"
}

apply_account_env() {
  local config_dir="$1"
  mkdir -p "$config_dir/colab-cli"

  export CLOUDSDK_CONFIG="$config_dir"
  export GOOGLE_APPLICATION_CREDENTIALS="$config_dir/application_default_credentials.json"
  export COLAB_CLI_CONFIG="$config_dir/colab-cli/sessions.json"
  export MULTI_COLAB_IDE_ACCOUNT_DIR="$config_dir"

  persist_active_profile "$config_dir"
}

account_label_for_dir() {
  local target="$1"
  load_accounts 2>/dev/null || return 1
  local i
  for i in "${!ACCOUNT_DIRS[@]}"; do
    if [[ "${ACCOUNT_DIRS[$i]}" == "$target" ]]; then
      echo "${ACCOUNT_LABELS[$i]}"
      return 0
    fi
  done
  return 1
}

gcloud_account_email() {
  gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -1
}

adc_configured() {
  [[ -f "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]
}

colab_whoami() {
  local colab_cmd="${MULTI_COLAB_IDE_COLAB_BIN:-colab}"
  if command -v "$colab_cmd" >/dev/null 2>&1; then
    local config_args=()
    if [[ -n "${COLAB_CLI_CONFIG:-}" ]]; then
      config_args=(--config "$COLAB_CLI_CONFIG")
    fi
    "$colab_cmd" --auth=adc "${config_args[@]}" whoami 2>&1
  else
    echo "(colab CLI not installed)"
  fi
}
