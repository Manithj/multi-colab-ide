# multi-colab-ide: auto-load the last selected Google profile in new shells.
# Compatible with bash and zsh. Sourced by install.sh from ~/.bashrc / ~/.zshrc.

_toolkit_dir="${MULTI_COLAB_IDE_HOME:-$HOME/multi-colab-ide}"

# Resolve this file's path (bash + zsh).
if [[ -n "${BASH_VERSION:-}" && -f "${BASH_SOURCE[0]:-}" ]]; then
  _env_script="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  # shellcheck disable=SC2296
  _env_script="${${(%):-%x}:A}"
else
  _env_script="${0:-}"
fi

if [[ -n "$_env_script" && -f "$_env_script" ]]; then
  while [[ -L "$_env_script" ]]; do
    _env_dir="$(cd "$(dirname "$_env_script")" && pwd)"
    _env_script="$(readlink "$_env_script")"
    [[ "$_env_script" != /* ]] && _env_script="$_env_dir/$_env_script"
  done
  _toolkit_dir="$(cd "$(dirname "$_env_script")" && pwd)"
fi

if [[ -f "$_toolkit_dir/lib/load-profile.sh" ]]; then
  # shellcheck source=lib/load-profile.sh
  source "$_toolkit_dir/lib/load-profile.sh"
  multi_colab_ide_load_active_profile
fi

unset _toolkit_dir _env_script _env_dir
