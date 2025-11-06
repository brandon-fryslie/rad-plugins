# proj2 (p2) - cd to a project directory using fzf
# Supports multiple project directories via PROJECTS_DIRS (array)
# or single directory via PROJECTS_DIR (backward compatibility)

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

  # Check if session already exists
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Attaching to existing tmux session: $session_name"
    tmux attach-session -t "$session_name"
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
      # Attach to the session
      tmux attach-session -t "$session_name"
    else
      # No clod available, just start with default shell
      tmux new-session -s "$session_name" -c "$project_path"
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
  local selected project_name proj_dir parent_dir action
  local -a proj_dirs all_projects selected_items
  local full_path

  # Check if fzf is available
  if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install fzf to use proj2." >&2
    return 1
  fi

  # Get current project directories
  proj_dirs=(${(z)$(_proj2_get_dirs)})

  # Collect all projects with parent directory prefix and full paths
  local -A project_paths
  for proj_dir in "${proj_dirs[@]}"; do
    if [[ -d $proj_dir ]]; then
      parent_dir="${proj_dir:t}"
      for project in "$proj_dir"/*(/N:t); do
        local display="${parent_dir}/${project}"
        all_projects+=("$display")
        project_paths[$display]="${proj_dir}/${project}"
      done
    fi
  done

  if [[ ${#all_projects[@]} -eq 0 ]]; then
    echo "No projects found in: ${proj_dirs[*]}" >&2
    return 1
  fi

  # If an argument is provided, use it as initial query
  local initial_query="$1"

  # Build preview command that finds the actual path
  local preview_script="
    project_display={}
    project_name=\${project_display##*/}
    for base_dir in ${(qq)proj_dirs[@]}; do
      test_path=\"\${base_dir}/\${project_name}\"
      if [[ -d \"\$test_path\" ]]; then
        echo \"Path: \$test_path\"
        echo \"\"
        ls -lah \"\$test_path\" 2>/dev/null | head -40
        break
      fi
    done
  "

  # Use fzf to select project(s) with multiple actions
  selected=$(printf '%s\n' "${all_projects[@]}" | fzf \
    --multi \
    --height=60% \
    --reverse \
    --prompt="Project: " \
    --query="$initial_query" \
    --header="ENTER=screen session | CTRL-E=cd+edit | CTRL-G=github | CTRL-P=print path | TAB=multi-select" \
    --bind "ctrl-e:execute-silent(echo {+} > /tmp/proj2-action)+accept" \
    --bind "ctrl-g:execute-silent(echo {+} > /tmp/proj2-github)+accept" \
    --bind "ctrl-p:execute-silent(echo {+} > /tmp/proj2-print)+accept" \
    --preview="$preview_script" \
    --preview-window=right:50%:wrap \
    --select-1 \
    --exit-0)

  if [[ -z $selected ]]; then
    # Check for special actions
    if [[ -f /tmp/proj2-action ]]; then
      action="edit"
      selected=$(<"/tmp/proj2-action")
      rm -f /tmp/proj2-action
    elif [[ -f /tmp/proj2-github ]]; then
      action="github"
      selected=$(<"/tmp/proj2-github")
      rm -f /tmp/proj2-github
    elif [[ -f /tmp/proj2-print ]]; then
      action="print"
      selected=$(<"/tmp/proj2-print")
      rm -f /tmp/proj2-print
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

    edit)
      # CD and open editor
      local first="${selected_items[1]}"
      full_path="${project_paths[$first]}"
      if [[ -d "$full_path" ]]; then
        cd "$full_path"
        ${VISUAL:-${EDITOR:-vi}} .
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

    print)
      # Print paths
      for item in "${selected_items[@]}"; do
        echo "${project_paths[$item]}"
      done
      ;;
  esac
}

# Create alias 'p2' for quick access
alias p2='proj2'
