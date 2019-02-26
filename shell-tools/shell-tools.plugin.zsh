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

# import exec-find
source "${0:a:h}/exec-find-zaw.zsh"
