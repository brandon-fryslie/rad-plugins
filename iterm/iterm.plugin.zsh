#### iTerm Integration

### Includes iTerm integration in rad-shell.  Installs the integration source code if necessary.
### See here for more information: https://iterm2.com/documentation-shell-integration.html

function rad-shell-source-iterm-integration() {
  local SHELL_INTEGRATION_SCRIPT_PATH="$HOME/.iterm2_shell_integration.zsh"

  # detect if
  if [[ ! -f $SHELL_INTEGRATION_SCRIPT_PATH ]]; then
    curl -sSL https://iterm2.com/shell_integration/zsh -o $SHELL_INTEGRATION_SCRIPT_PATH
  fi

  source $SHELL_INTEGRATION_SCRIPT_PATH
}

if [[ $TERM_PROGRAM == "iTerm.app" ]]; then
  rad-shell-source-iterm-integration
fi
