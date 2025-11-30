# proj2 (p2) - cd to a project directory using fzf
# Supports multiple project directories via PROJECTS_DIRS (array)
# or single directory via PROJECTS_DIR (backward compatibility)

# Get the directory where this script is located
typeset -g _PROJ2_SCRIPT_DIR="${${(%):-%x}:A:h}"

# Create or attach to tmux session for project
_proj2_screen_session() {
  local project_path="$1"
  local session_name="${project_path:t}"  # Use directory name as session name

  # Check if tmux is installed
  if ! command -v tmux &> /dev/null; then
    echo "Error: tmux is not installed. Falling back to simple cd." >&2
    cd "$project_path"
    return 0
  fi

  # Reload tmux config to pick up any changes
  tmux source-file ~/.tmux.conf 2>/dev/null || true

  # Change to project directory first
  cd "$project_path"

  # Determine if we're already inside a tmux session
  local inside_tmux=0
  [[ -n "$TMUX" ]] && inside_tmux=1

  # Helper to attach/switch to session (uses switch-client if inside tmux)
  _proj2_goto_session() {
    local target="$1"
    if (( inside_tmux )); then
      tmux switch-client -t "$target"
    else
      tmux attach-session -t "$target"
    fi
  }

  # Check if session already exists
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Switching to tmux session: $session_name"
    _proj2_goto_session "$session_name"
  else
    echo "Creating new tmux session: $session_name"

    # Create new tmux session with project directory as start directory
    # First window: run clod if available
    if (( $+commands[clod] )); then
      tmux new-session -s "$session_name" -c "$project_path" -d -n "clod" clod
      # Second window: regular shell (no command specified = use default shell)
      tmux new-window -t "$session_name" -c "$project_path" -n "shell"
      # Select the shell window
      tmux select-window -t "$session_name:shell"
      # Attach/switch to the session
      _proj2_goto_session "$session_name"
    else
      # No clod available - behavior differs if inside tmux or not
      if (( inside_tmux )); then
        # Create detached, then switch
        tmux new-session -s "$session_name" -c "$project_path" -d
        tmux switch-client -t "$session_name"
      else
        # Create and attach directly
        tmux new-session -s "$session_name" -c "$project_path"
      fi
    fi
  fi
}

# Get project directories (dynamically checks variables each time)
_proj2_get_dirs() {
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

function proj2 {
  local selected project_name proj_dir parent_dir action display display_with_icon
  local -a proj_dirs all_projects selected_items active_projects inactive_projects
  local full_path

  # Check if fzf is available
  if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install fzf to use proj2." >&2
    return 1
  fi

  # Get current project directories
  proj_dirs=(${(z)$(_proj2_get_dirs)})

  # Get list of active tmux sessions
  local -A project_paths active_sessions
  if command -v tmux &> /dev/null; then
    local session_list=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
    for session in ${(f)session_list}; do
      active_sessions[$session]=1
    done
  fi

  # Collect all projects with parent directory prefix and full paths
  # Separate active (with tmux session) and inactive projects
  for proj_dir in "${proj_dirs[@]}"; do
    if [[ -d "$proj_dir" ]]; then
      parent_dir="${proj_dir:t}"
      for project in "$proj_dir"/*(/N:t); do
        display="${parent_dir}/${project}"

        # Check if this project has an active tmux session
        if [[ -n ${active_sessions[$project]} ]]; then
          display_with_icon="● ${display}"
          active_projects+=("$display_with_icon")
        else
          display_with_icon="$display"
          inactive_projects+=("$display_with_icon")
        fi

        # Map display name to actual path
        project_paths[$display_with_icon]="${proj_dir}/${project}"
      done
    fi
  done

  # Combine: active projects first, then inactive
  all_projects=("${active_projects[@]}" "${inactive_projects[@]}")

  if [[ ${#all_projects[@]} -eq 0 ]]; then
    echo "No projects found in: ${proj_dirs[*]}" >&2
    return 1
  fi

  # If an argument is provided, use it as initial query
  local initial_query="$1"

  # Build preview command - call external script with project dirs as arguments
  # Use (qq) for double quoting each array element to handle spaces
  local preview_cmd="${(qq)_PROJ2_SCRIPT_DIR}/.proj2-preview.sh {} ${(@qq)proj_dirs}"

  # Create temp files for active/inactive project lists (used by filter script)
  local active_file=$(mktemp)
  local inactive_file=$(mktemp)
  trap "rm -f '$active_file' '$inactive_file'" EXIT

  printf '%s\n' "${active_projects[@]}" > "$active_file"
  printf '%s\n' "${inactive_projects[@]}" > "$inactive_file"

  # Build filter command - keeps active sessions at top even during search
  local filter_cmd="${(qq)_PROJ2_SCRIPT_DIR}/.proj2-filter.sh {q} ${(qq)active_file} ${(qq)inactive_file}"

  # Use fzf to select project(s) with multiple actions
  # --disabled prevents fzf's built-in filtering; we use custom filter via reload
  selected=$(fzf \
    --multi \
    --height=60% \
    --reverse \
    --prompt="Project: " \
    --query="$initial_query" \
    --header="TAB=multi-select  CTRL-G=github" \
    --disabled \
    --bind "start:reload:$filter_cmd" \
    --bind "change:reload:$filter_cmd" \
    --bind "ctrl-g:execute-silent(echo {+} > /tmp/proj2-github)+accept" \
    --preview="$preview_cmd" \
    --preview-window=right:50%:wrap \
    --select-1 \
    --exit-0)

  if [[ -z $selected ]]; then
    # Check for special actions
    if [[ -f /tmp/proj2-github ]]; then
      action="github"
      selected=$(<"/tmp/proj2-github")
      rm -f /tmp/proj2-github
    else
      # User cancelled
      return 1
    fi
  else
    action="cd"
  fi

  # Handle multi-select (split by newlines)
  selected_items=("${(@f)selected}")

  case $action in
    cd)
      # CD to first selected project and attach to/create screen session
      local first="${selected_items[1]}"
      full_path="${project_paths[$first]}"
      if [[ -d "$full_path" ]]; then
        _proj2_screen_session "$full_path"
      else
        echo "Error: Directory not found: $full_path" >&2
        return 1
      fi
      ;;

    github)
      # Open in GitHub (if git repo)
      for item in "${selected_items[@]}"; do
        full_path="${project_paths[$item]}"
        if [[ -d "$full_path/.git" ]]; then
          (cd "$full_path" && gh repo view --web 2>/dev/null || echo "Not a GitHub repo: $item")
        else
          echo "Not a git repo: $item"
        fi
      done
      ;;
  esac
}

# Create alias 'p2' for quick access
alias p2='proj2'
