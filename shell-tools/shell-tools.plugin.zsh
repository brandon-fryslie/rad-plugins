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

#################################################################
# cd to a dir in ~/projects
# because we type that a lot
# includes tab completions
#################################################################

PROJECTS_DIR=${PROJECTS_DIR:-${HOME}/projects}

function proj {
  cd "${PROJECTS_DIR}/$1"
}
_proj_completion() {
  reply=($(exec ls -m "${PROJECTS_DIR}" | sed -e 's/,//g' | tr -d '\n'))
}
compctl -K _proj_completion proj
#################################################################

### cdtl - cd to git top level repo directory
function cdtl() {
  local repo_dir
  repo_dir="$(git rev-parse --show-toplevel 2>&1)"
  [[ $? != 0 ]] || [[ -z $repo_dir ]] && { rad-red "Not a git repo"; return 1; }
  cd $repo_dir
}

# setup direnv
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)" 1>/dev/null
fi

# import exec-find
source "${0:a:h}/exec-find-zaw.zsh"
