# Load the last multi-colab-ide profile when CLOUDSDK_CONFIG is unset.
multi_colab_ide_load_active_profile() {
  if [[ -n "${CLOUDSDK_CONFIG:-}" ]]; then
    return 0
  fi

  local active_file="${MULTI_COLAB_IDE_STATE_DIR:-${HOME}/.config/multi-colab-ide}/active"
  if [[ ! -f "$active_file" ]]; then
    return 0
  fi

  local active
  active="$(<"$active_file")"
  if [[ -z "$active" || ! -d "$active" ]]; then
    return 0
  fi

  export CLOUDSDK_CONFIG="$active"
  export GOOGLE_APPLICATION_CREDENTIALS="${CLOUDSDK_CONFIG}/application_default_credentials.json"
  export COLAB_CLI_CONFIG="${CLOUDSDK_CONFIG}/colab-cli/sessions.json"
  export MULTI_COLAB_IDE_ACCOUNT_DIR="${CLOUDSDK_CONFIG}"
}
