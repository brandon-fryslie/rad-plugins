# proj2 (p2) - cd to a project directory using fzf
# Supports multiple project directories via PROJECTS_DIRS (array)
# or single directory via PROJECTS_DIR (backward compatibility)

# Cleanup orphaned abduco sessions on startup
# Called when this script is sourced to clean up abduco sessions
# that have no corresponding tmux session and no preserve marker
_proj2_cleanup_orphans() {
  # Silently skip if abduco not installed
  command -v abduco &>/dev/null || return 0

  # Get list of abduco sessions matching *-clod pattern
  local abduco_sessions=$(abduco 2>/dev/null | tail -n +2 | awk '{print $4}' | grep -- '-clod$' || true)

  [[ -z "$abduco_sessions" ]] && return 0

  # Get list of active tmux sessions
  local tmux_sessions=$(tmux ls -F '#{session_name}' 2>/dev/null || true)

  # Check each abduco session
  # Use process substitution to ensure echo output is visible
  while read -r abduco_session; do
    # Extract project/session name (remove -clod suffix)
    local session_name="${abduco_session%-clod}"
    local preserve_marker="$HOME/.proj2/preserving/$session_name"

    # Check if tmux session exists OR preserve marker exists
    local has_tmux_session=false
    local has_preserve_marker=false

    if echo "$tmux_sessions" | grep -q "^${session_name}$"; then
      has_tmux_session=true
    fi

    if [[ -f "$preserve_marker" ]]; then
      has_preserve_marker=true
    fi

    # If neither exists, this is an orphan - kill it
    if ! $has_tmux_session && ! $has_preserve_marker; then
      echo "Cleaning up orphaned abduco session: $abduco_session"
      abduco -k "$abduco_session" 2>/dev/null || true
    fi
  done < <(echo "$abduco_sessions")
}

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

    # Create new tmux session with two windows
    # Start with initial session in detached mode (creates window 0)
    tmux new-session -s "$session_name" -c "$project_path" -d

    # Window 0: run clod if available
    if (( $+commands[clod] )); then
      # Check if abduco is available
      if (( $+commands[abduco] )); then
        local abduco_session="${session_name}-clod"
        # Use abduco to wrap clod - this allows clod to survive tmux server restarts
        # -e '' disables escape key (makes abduco transparent)
        # -A attaches to existing session or creates new one
        tmux send-keys -t "$session_name:0" "abduco -e '' -A '$abduco_session' clod" C-m
      else
        # Fallback to plain clod if abduco not available
        tmux send-keys -t "$session_name:0" "clod" C-m
      fi
    fi

    # Create window 1: zsh (ready for commands)
    # This window already starts in the project directory, so no command needed
    tmux new-window -t "$session_name" -c "$project_path"

    # Select window 0 (so you start in clod)
    tmux select-window -t "$session_name:0"

    # Set up cleanup hook for when session closes normally
    # This will kill the abduco session unless we're in preserve mode
    if (( $+commands[abduco] )); then
      local cleanup_script="$HOME/.proj2/cleanup.sh"
      if [[ -x "$cleanup_script" ]]; then
        tmux set-hook -t "$session_name" session-closed "run-shell '$cleanup_script $session_name'"
      fi
    fi

    # Attach to the session
    tmux attach-session -t "$session_name"
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
  local direct_project=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -p|--project)
        direct_project="$2"
        shift 2
        ;;
      --tmux-restart)
        # Run the prepare-restart function and exit
        proj2-prepare-restart
        return $?
        ;;
      *)
        # Treat as initial query for fzf
        local initial_query="$1"
        shift
        ;;
    esac
  done

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

  # If -p flag was used, directly open that project
  if [[ -n $direct_project ]]; then
    # Check if the project exists in our project_paths
    if [[ -n ${project_paths[$direct_project]} ]]; then
      full_path="${project_paths[$direct_project]}"
      if [[ -d "$full_path" ]]; then
        _proj2_screen_session "$full_path"
        return 0
      else
        echo "Error: Directory not found: $full_path" >&2
        return 1
      fi
    else
      echo "Error: Project '$direct_project' not found in known projects." >&2
      echo "Available projects:" >&2
      printf '%s\n' "${all_projects[@]}" | sort >&2
      return 1
    fi
  fi

  # Check if fzf is available (only needed for interactive mode)
  if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install fzf to use proj2." >&2
    return 1
  fi

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

# Prepare for tmux server restart by creating preserve markers
# This allows abduco sessions to survive `tmux kill-server`
function proj2-prepare-restart {
  if ! command -v abduco &>/dev/null; then
    echo "Error: abduco is not installed. This command requires abduco." >&2
    return 1
  fi

  if ! command -v tmux &>/dev/null; then
    echo "Error: tmux is not installed." >&2
    return 1
  fi

  # Ensure preserve directory exists
  mkdir -p ~/.proj2/preserving

  # Get list of abduco sessions matching *-clod pattern
  local abduco_sessions=$(abduco 2>/dev/null | tail -n +2 | awk '{print $4}' | grep -- '-clod$' || true)

  if [[ -z "$abduco_sessions" ]]; then
    echo "No proj2 abduco sessions found. Nothing to preserve."
    return 0
  fi

  # Get list of active tmux sessions
  local tmux_sessions=$(tmux ls -F '#{session_name}' 2>/dev/null || true)

  if [[ -z "$tmux_sessions" ]]; then
    echo "No active tmux sessions found."
    return 0
  fi

  local count=0

  # Create preserve markers for sessions that exist in both abduco and tmux
  # Use process substitution to avoid subshell issues with count variable
  while read -r abduco_session; do
    # Extract session name (remove -clod suffix)
    local session_name="${abduco_session%-clod}"

    # Check if corresponding tmux session exists
    if echo "$tmux_sessions" | grep -q "^${session_name}$"; then
      local preserve_marker="$HOME/.proj2/preserving/$session_name"
      touch "$preserve_marker"
      echo "Created preserve marker for session: $session_name"
      ((count++))
    fi
  done < <(echo "$abduco_sessions")

  if [[ $count -eq 0 ]]; then
    echo "No matching tmux/abduco session pairs found to preserve."
    return 0
  fi

  echo ""
  echo "Preserve markers created for $count session(s)."
  echo ""
  echo "You can now safely run: tmux kill-server"
  echo "After restarting tmux and reattaching to your sessions,"
  echo "the clod processes will still be running in their abduco sessions."
}

# Create alias 'p2' for quick access
alias p2='proj2'

# Tab completion is defined in shell-tools/functions/_proj2

# Run orphan cleanup when this script is sourced
_proj2_cleanup_orphans
