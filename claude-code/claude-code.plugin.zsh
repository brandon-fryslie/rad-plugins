happy() {
   HAPPY_SERVER_URL=https://happy-server.sanctuary.gdn HAPPY_HOME_DIR=~/.happy-homelab command happy "$@"
}

# Ensure this runs in a subshell - note the parens rather than curly braces
claad () (
    export SHELL=bash
    claude --dangerously-skip-permissions "$@"
)

# Ensure this runs in a subshell - note the parens rather than curly braces
clod () (
    happy claad "$@"
)

setup_claude_config_dir() {
  local service=$1 # minimax or zai
  local claude_config_dir="$DOTFILES_DIR/config/claude"
  local service_config_dir="${claude_config_dir}.${service}"

  # TODO: symlink things?
}

get_claude_config_dir() {
  local main_config_dir="$DOTFILES_DIR/config/claude"
  [[ -z $1 ]] && { echo "${main_config_dir}"; return; }
  local service_config_dir="${main_config_dir}.${1}"
  mkdir -p "${service_config_dir}"
  echo "${service_config_dir}"
}

claude_service() {
  local service_name=$1; shift
  [[ -z $service_name ]] && { rad-red "ERROR: Must provide service name"; return 1; }
  local claude_config_dir="$(get_claude_config_dir)"
  local claude_service_config_dir="$(get_claude_config_dir "${service_name}")"
  export CLAUDE_CONFIG_DIR="${claude_service_config_dir}"
  pnpm dlx @dotenvx/dotenvx run -f "${claude_config_dir}/.env.${service_name}" -- claude --dangerously-skip-permissions --settings "${claude_config_dir}/settings.${service_name}.json" "$@"
}

mlod() {
  claude_service minimax "$@"
}

zlod() {
  claude_service zai "$@"
}
