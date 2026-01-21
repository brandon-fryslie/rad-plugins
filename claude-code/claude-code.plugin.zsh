# Ensure this runs in a subshell - note the parens rather than curly braces
clod () (
    export SHELL=bash
    claude-chill -- claude --dangerously-skip-permissions "$@"
)

mlod() {
  local claude_config_dir="$DOTFILES_DIR/config/claude"
  dotenvx run -f $claude_config_dir/.env.minimax -- clod --settings $claude_config_dir/settings.minimax.json "$@"
}

zlod() {
  local claude_config_dir="$DOTFILES_DIR/config/claude"
  dotenvx run -f $claude_config_dir/.env.zai -- clod --dangerously-skip-permissions --settings $claude_config_dir/settings.zai.json "$@"
}
