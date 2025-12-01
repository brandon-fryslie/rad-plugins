# example of a depends_on directive (format 1, plugin id only)
# <rad directive prefix> <rad directive action> <plugin id>
# ☢ depends_on molovo/revolver
# @rad@ depends_on molovo/revolver

# example of a depends_on directive (format 2, single function)
# ☢ depends_on _revolver_stop molovo/revolver

# example of a depends_on directive (format 3, multi function)
# note: this does not control what functions are available.  this will throw an error
# if the functions do not exist after sourcing the plugin
# <rad directive prefix> <function list> <plugin id>
# ☢ depends_on _revolver_start,_revolver_stop molovo/revolver

# Import proj function (supports multiple project directories)
source "${0:a:h}/proj.zsh"

# Import proj2 function (fzf-based project selector)
source "${0:a:h}/proj2.zsh"

### cdtl - cd to git top level repo directory
function cdtl() {
  local repo_dir
  repo_dir="$(git rev-parse --show-toplevel 2>&1)"
  [[ $? != 0 ]] || [[ -z $repo_dir ]] && { rad-red "Not a git repo"; return 1; }
  cd "$repo_dir"
}

# setup direnv
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)" 1>/dev/null
fi

# import exec-find
source "${0:a:h}/exec-find-zaw.zsh"
source "${0:a:h}/sgpt-zsh.zsh"
source "${0:a:h}/macos-codesign.zsh"
source "${0:a:h}/tmux-test.zsh"

# Import workspace-actions (contextual action menu)
source "${0:a:h}/workspace-actions.zsh"

# Key binding for workspace-actions
bindkey '^[w' workspace-actions  # opt+w

### find-zsh-sources - Recursively find all files sourced from shell config
# Capture the plugin directory at definition time
typeset -g SHELL_TOOLS_PLUGIN_DIR="${0:a:h}"

function find-zsh-sources() {
  "${SHELL_TOOLS_PLUGIN_DIR}/bin/find_zsh_sources.py" "$@"
}
