#### plugin for abduco completions
# Plugin disabled - early return
return 0

source "${0:a:h}/abduco-completions.zsh"



: ${PROJECTS_DIR:="${HOME}/icode"}

typeset -ga _ABDOOKIE_PROJECT_DIRS_REAL

_abdookie_check_deps() {
  if ! command -v abduco &>/dev/null; then
    rad-yellow "abdookie plugin: requires abduco. Install with: brew install abduco"
    return 1
  fi
  return 0
}

_abdookie_init_project_dirs() {
  _ABDOOKIE_PROJECT_DIRS_REAL=()

  local -a dirs
  if [[ -n $PROJECT_DIRS ]]; then
    # Handle both array and whitespace-separated string
    if [[ ${(t)PROJECT_DIRS} == *array* ]]; then
      dirs=("${PROJECT_DIRS[@]}")
    else
      dirs=(${=PROJECT_DIRS})
    fi
  elif [[ -n $PROJECTS_DIR ]]; then
    dirs=("$PROJECTS_DIR")
  fi

  # Resolve symlinks for all directories
  local dir
  for dir in "${dirs[@]}"; do
    _ABDOOKIE_PROJECT_DIRS_REAL+=("${dir:A}")
  done
}

_abdookie_get_session_command() {
  if command -v dvtm &>/dev/null; then
    echo "dvtm"
  else
    echo "zsh"
  fi
}

_abdookie_chpwd() {
  [[ -n $ABDUCO_SESSION ]] && return

  local rpwd=${PWD:A}
  local project_dir_real

  for project_dir_real in "${_ABDOOKIE_PROJECT_DIRS_REAL[@]}"; do
    [[ $rpwd == $project_dir_real/* ]] || continue

    local rel=${rpwd#$project_dir_real/}
    [[ $rel == */* ]] && return

    local project_name="${project_dir_real:t}"
    local session_name="${project_name}-${rel}"
    local cmd=$(_abdookie_get_session_command)

    abduco -A "$session_name" "$cmd"
    return
  done
}

_abdookie_check_hook_override() {
  # Check if chpwd was directly defined (not using add-zsh-hook)
  if [[ $(whence -w chpwd) == "chpwd: function" ]] && ! functions chpwd | grep -q "chpwd_functions"; then
    rad-yellow "abdookie plugin: WARNING - chpwd() was directly defined, overriding hook system. Use 'add-zsh-hook chpwd' instead."
    return 1
  fi
  return 0
}

# alias abd="abduco -A $(basename $PWD) zsh"

abd() {
  # parse argumnets like this:
  # `abd <project name>` ->
  # - cd to a 'project directory', a direct subdirectory to a dir in PROJECTS_DIRS
  # - get 'basename' from the path (the name of the subdirectory)
  # - derive the abduco session name: "<basename/project name>-<abduco session suffix>"
  # - abduco-session-suffix is either: value of abd -s|--session-suffix parameter, $ABDUCO_SESSION_SUFFIX, or defaults to "$(basename of the parent directory)", e.g., proj1-icode if the directory is ~/icode/proj1
  # - run abduco -A <abduco session name>
  true
}

_abd_completion() {
  reply=($(abduco -l 2>/dev/null | tail -n +2 | awk '{print $4}'))
}
compctl -K _abd_completion abd

# Initialize plugin
_abdookie_check_deps || return
_abdookie_init_project_dirs

# Register chpwd hook
autoload -Uz add-zsh-hook
# add-zsh-hook chpwd _abdookie_chpwd
# add-zsh-hook chpwd _abdookie_check_hook_override
