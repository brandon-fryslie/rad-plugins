# kept for historical reasons
# this is about as minimal as you can get for zsh completions
#################################################################

PROJECTS_DIR=${PROJECTS_DIR:-${HOME}/projects}

function proj-classic {
  cd "${PROJECTS_DIR}/$1"
}
_proj_classic_completion() {
  reply=($(exec ls -m "${PROJECTS_DIR}" | sed -e 's/,//g' | tr -d '\n'))
}
compctl -K _proj_classic_completion proj-classic
#################################################################