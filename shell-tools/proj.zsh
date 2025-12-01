# proj - cd to a project directory
# Supports multiple project directories via PROJECTS_DIRS (array)
# or single directory via PROJECTS_DIR (backward compatibility)

# Get project directories (dynamically checks variables each time)
_proj_get_dirs() {
  local -a dirs

  if [[ -n $PROJECTS_DIRS ]]; then
    # Handle both array and whitespace-separated string
    if [[ ${(t)PROJECTS_DIRS} == *array* ]]; then
      dirs=("${PROJECTS_DIRS[@]}")
    else
      dirs=(${=PROJECTS_DIRS})
    fi
  elif [[ -n $PROJECTS_DIR ]]; then
    dirs=("$PROJECTS_DIR")
  else
    # Default fallback
    dirs=("${HOME}/projects")
  fi

  echo "${dirs[@]}"
}

function proj {
  local project_name="$1"

  if [[ -z $project_name ]]; then
    echo "Usage: proj <project-name>"
    return 1
  fi

  # Handle parent_dir/project_name format from completion
  if [[ $project_name == */* ]]; then
    # Extract just the project name (everything after the last /)
    project_name="${project_name##*/}"
  fi

  # Get current project directories
  local -a proj_dirs
  proj_dirs=(${(z)$(_proj_get_dirs)})

  # Search through each project directory
  local proj_dir
  for proj_dir in "${proj_dirs[@]}"; do
    if [[ -d "${proj_dir}/${project_name}" ]]; then
      cd "${proj_dir}/${project_name}"
      return 0
    fi
  done

  echo "Project '$project_name' not found in any of: ${proj_dirs[*]}"
  return 1
}

_proj_completion() {
  local proj_dir project parent_dir
  local -a completions proj_dirs
  local -a descriptions matches

  # Get current project directories
  proj_dirs=(${(z)$(_proj_get_dirs)})

  # Collect all projects with parent directory prefix
  for proj_dir in "${proj_dirs[@]}"; do
    if [[ -d "$proj_dir" ]]; then
      parent_dir="${proj_dir:t}"
      for project in "$proj_dir"/*(/N:t); do
        completions+=("${parent_dir}/${project}")
        descriptions+=("${parent_dir}/${project}")
      done
    fi
  done

  # Use compadd with substring matching
  _wanted projects expl 'project' compadd -M 'r:|/=* r:|=*' -d descriptions -a completions
}

# Try to use modern completion system, fall back to compctl
if (( $+functions[compdef] )); then
  compdef _proj_completion proj
else
  # Fallback for older completion - just list all without filtering
  _proj_completion_fallback() {
    local proj_dir project parent_dir
    local -a proj_dirs

    proj_dirs=(${(z)$(_proj_get_dirs)})

    for proj_dir in "${proj_dirs[@]}"; do
      if [[ -d "$proj_dir" ]]; then
        parent_dir="${proj_dir:t}"
        for project in "$proj_dir"/*(/N:t); do
          reply+=("${parent_dir}/${project}")
        done
      fi
    done
  }
  compctl -K _proj_completion_fallback proj
fi
