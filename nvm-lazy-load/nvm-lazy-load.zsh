# This plugin allows lazy-loading nvm when any global node command is called
#
# Adds stubs for each global node command to the environment, then loads nvm and
# replaces them when the stub is called
#
# Some smarts are in place to source the nvm script a minimum number of times
#
# Credit goes to user 'sscotth' on reddit
# https://www.reddit.com/r/node/comments/4tg5jg/lazy_load_nvm_for_faster_shell_start/d5ib9fs/

load_nvm () {
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_comple
  zstyle ':nvm-lazy-load' nvm-loaded 'yes'
}

declare -a _RAD_NVM_LAZY_LOAD_NODE_GLOBALS
setup_node_aliases() {
  # Do not create stubs for node globals if no versions of node are installed
  if [[ -d ~/.nvm/versions/node ]]; then
    _RAD_NVM_LAZY_LOAD_NODE_GLOBALS=(`find ~/.nvm/versions/node -maxdepth 3 -type l -wholename '*/bin/*' | xargs -n1 basename | sort | uniq`)
    _RAD_NVM_LAZY_LOAD_NODE_GLOBALS+=("node")
  fi

  _RAD_NVM_LAZY_LOAD_NODE_GLOBALS+=("nvm")

  local script
  for cmd in "${_RAD_NVM_LAZY_LOAD_NODE_GLOBALS[@]}"; do
      script=$(cat <<-EOSCRIPT
          ${cmd}() {
              unset -f ${_RAD_NVM_LAZY_LOAD_NODE_GLOBALS}
              zstyle -t ':nvm-lazy-load' nvm-loaded 'yes' || load_nvm
              ${cmd} \$@
          }
EOSCRIPT
  )
      eval "$script"
  done
}

export NVM_DIR="$HOME/.nvm"

# Do not setup aliases if nvm is not installed
if command -v nvm >/dev/null 2>&1; then
  setup_node_aliases
fi
