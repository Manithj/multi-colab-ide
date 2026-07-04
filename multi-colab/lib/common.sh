#!/usr/bin/env bash
# Shared helpers for multi-colab multi-account toolkit.

_script="${BASH_SOURCE[0]}"
while [[ -L "$_script" ]]; do
  _dir="$(cd "$(dirname "$_script")" && pwd)"
  _script="$(readlink "$_script")"
  [[ "$_script" != /* ]] && _script="$_dir/$_script"
done
TOOLKIT_DIR="$(cd "$(dirname "$_script")/.." && pwd)"
ACCOUNTS_FILE="${MULTI_COLAB_ACCOUNTS:-$TOOLKIT_DIR/accounts.conf}"

# Colab CLI needs these scopes for ADC (see colab_cli/auth.py).
COLAB_ADC_SCOPES="openid,https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/colaboratory"

cursor_bin() {
  if command -v cursor >/dev/null 2>&1; then
    command -v cursor
  elif [[ -x "$HOME/.local/bin/cursor" ]]; then
    echo "$HOME/.local/bin/cursor"
  else
    echo "cursor"
  fi
}

expand_path() {
  # shellcheck disable=SC2001
  echo "$1" | sed "s|^~|$HOME|"
}

load_accounts() {
  if [[ ! -f "$ACCOUNTS_FILE" ]]; then
    echo "Accounts file not found: $ACCOUNTS_FILE" >&2
    echo "Run: $TOOLKIT_DIR/install.sh" >&2
    return 1
  fi

  ACCOUNTS=()
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
    ACCOUNTS+=("$id|$label|$dir")
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

apply_account_env() {
  local config_dir="$1"
  mkdir -p "$config_dir/colab-cli"

  export CLOUDSDK_CONFIG="$config_dir"
  export GOOGLE_APPLICATION_CREDENTIALS="$config_dir/application_default_credentials.json"
  export COLAB_CLI_CONFIG="$config_dir/colab-cli/sessions.json"
  export MULTI_COLAB_ACCOUNT_DIR="$config_dir"

  # Persist choice for verify/account-switch in new shells (optional).
  mkdir -p "$HOME/.config/multi-colab"
  printf '%s\n' "$config_dir" >"$HOME/.config/multi-colab/active"
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
  if command -v colab >/dev/null 2>&1; then
    local config_args=()
    if [[ -n "${COLAB_CLI_CONFIG:-}" ]]; then
      config_args=(--config "$COLAB_CLI_CONFIG")
    fi
    colab --auth=adc "${config_args[@]}" whoami 2>&1
  else
    echo "(colab CLI not installed)"
  fi
}
