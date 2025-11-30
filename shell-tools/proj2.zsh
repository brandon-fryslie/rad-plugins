# proj2 (p2) - cd to a project directory using fzf
# Supports multiple project directories via PROJECTS_DIRS (array)
# or single directory via PROJECTS_DIR (backward compatibility)

# Get the directory where this script is located
typeset -g _PROJ2_SCRIPT_DIR="${${(%):-%x}:A:h}"

# ANSI color codes matching p10k theme
typeset -g _P2_RESET=$'\033[0m'
typeset -g _P2_BOLD=$'\033[1m'
typeset -g _P2_UL=$'\033[4m'
typeset -g _P2_META=$'\033[38;5;246m'
typeset -g _P2_CLEAN=$'\033[38;5;76m'
typeset -g _P2_STAGED=$'\033[38;5;40m'
typeset -g _P2_UNSTAGED=$'\033[38;5;160m'
typeset -g _P2_AHEAD=$'\033[38;5;39m'
typeset -g _P2_BEHIND=$'\033[38;5;178m'
typeset -g _P2_REMOTE=$'\033[38;5;28m'
typeset -g _P2_CONFLICT=$'\033[38;5;196m'

# Get compact git status for a project directory (p10k style)
# If second arg is a file path, writes result there (for async use)
_proj2_git_status() {
  local project_path="$1"
  local output_file="$2"

  local res=""

  if [[ -d "$project_path/.git" ]]; then
    cd "$project_path" 2>/dev/null || { [[ -n $output_file ]] && echo "" > "$output_file"; return; }

    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n $branch ]]; then
      # Parse git status -sb for efficiency (one command for most info)
      local status_line=$(git status -sb 2>/dev/null | head -1)

      # Extract ahead/behind from status line
      local ahead=0 behind=0
      if [[ $status_line =~ '\[ahead ([0-9]+)' ]]; then
        ahead=${match[1]:-0}
        ahead=${ahead//[^0-9]/}; ahead=${ahead:-0}
      fi
      if [[ $status_line =~ 'behind ([0-9]+)' ]]; then
        behind=${match[1]:-0}
        behind=${behind//[^0-9]/}; behind=${behind:-0}
      fi

      # Count changes from porcelain output
      local porcelain=$(git status --porcelain 2>/dev/null)
      local num_staged=0 num_unstaged=0 num_untracked=0 num_conflicted=0
      if [[ -n "$porcelain" ]]; then
        num_staged=$(echo "$porcelain" | grep -c '^[MADRC]' 2>/dev/null) || num_staged=0
        num_unstaged=$(echo "$porcelain" | grep -c '^.[MD]' 2>/dev/null) || num_unstaged=0
        num_untracked=$(echo "$porcelain" | grep -c '^??' 2>/dev/null) || num_untracked=0
        num_conflicted=$(echo "$porcelain" | grep -c '^UU\|^AA\|^DD' 2>/dev/null) || num_conflicted=0
      fi
      num_staged=${num_staged//[^0-9]/}; num_staged=${num_staged:-0}
      num_unstaged=${num_unstaged//[^0-9]/}; num_unstaged=${num_unstaged:-0}
      num_untracked=${num_untracked//[^0-9]/}; num_untracked=${num_untracked:-0}
      num_conflicted=${num_conflicted//[^0-9]/}; num_conflicted=${num_conflicted:-0}

      # Get remote info
      local remote_name=$(git config --get branch.$branch.remote 2>/dev/null)
      local remote_branch=${$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)#*/}

      # Time since last commit
      local last_commit_epoch=$(git log -1 --format='%ct' 2>/dev/null)
      local time_ago=""
      last_commit_epoch=${last_commit_epoch//[^0-9]/}
      if [[ -n $last_commit_epoch && $last_commit_epoch -gt 0 ]]; then
        local now=$(date +%s)
        local diff=$((now - last_commit_epoch))
        (( diff < 0 )) && diff=0
        if (( diff < 3600 )); then
          time_ago="$((diff / 60))m"
        elif (( diff < 86400 )); then
          time_ago="$((diff / 3600))h"
        elif (( diff < 604800 )); then
          time_ago="$((diff / 86400))d"
        elif (( diff < 2592000 )); then
          time_ago="$((diff / 604800))w"
        else
          time_ago="$((diff / 2592000))mo"
        fi
      fi

      # Build status string
      (( behind > 0 )) && res+="${_P2_BOLD}${_P2_BEHIND}-${_P2_UL}${behind}${_P2_RESET} "
      (( ahead > 0 )) && res+="${_P2_BOLD}${_P2_AHEAD}+${_P2_UL}${ahead}${_P2_RESET} "

      local display_branch=$branch
      (( ${#branch} > 20 )) && display_branch="${branch:0:8}…${branch: -8}"
      res+="${_P2_CLEAN}${display_branch}${_P2_RESET}"

      res+=" ${_P2_META}[${_P2_REMOTE}"
      if [[ -n $remote_branch ]]; then
        res+="${remote_name}/${remote_branch}"
        if (( num_staged > 0 || num_unstaged > 0 || num_untracked > 0 )); then
          res+=" ${_P2_BOLD}"
          (( num_staged > 0 )) && res+="${_P2_STAGED}S"
          (( num_unstaged > 0 )) && res+="${_P2_UNSTAGED}U"
          (( num_untracked > 0 )) && res+="${_P2_META}T"
          res+="${_P2_RESET}"
        fi
      else
        res+="${_P2_META}(none)"
      fi
      res+="${_P2_META}]${_P2_RESET}"

      (( num_conflicted > 0 )) && res+=" ${_P2_CONFLICT}~${num_conflicted}${_P2_RESET}"
      [[ -n $time_ago ]] && res+=" ${_P2_META}${time_ago}${_P2_RESET}"
    fi
  fi

  if [[ -n $output_file ]]; then
    echo "$res" > "$output_file"
  else
    echo "$res"
  fi
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

  # Collect all projects (git status loaded on-demand via CTRL-S)
  local -a active_with_mtime inactive_with_mtime
  local -a all_full_paths all_displays all_mtimes all_is_active
  local mtime
  local idx=0

  # Phase 1: Collect project metadata
  for proj_dir in "${proj_dirs[@]}"; do
    if [[ -d "$proj_dir" ]]; then
      parent_dir="${proj_dir:t}"
      for project in "$proj_dir"/*(/N:t); do
        display="${parent_dir}/${project}"
        full_path="${proj_dir}/${project}"
        mtime=$(stat -f %m "$full_path" 2>/dev/null || echo 0)

        all_full_paths+=("$full_path")
        all_displays+=("$display")
        all_mtimes+=("$mtime")
        [[ -n ${active_sessions[$project]} ]] && all_is_active+=(1) || all_is_active+=(0)

        # Map display name to actual path
        project_paths[$display]="$full_path"
        project_paths["● ${display}"]="$full_path"

        idx=$((idx + 1))
      done
    fi
  done

  # Phase 2: Build display strings (no git status yet - that's on-demand)
  for (( i=1; i <= idx; i++ )); do
    display="${all_displays[$i]}"
    mtime="${all_mtimes[$i]}"
    local is_active="${all_is_active[$i]}"

    # Check if this project has an active tmux session
    if [[ $is_active == 1 ]]; then
      display_with_icon="● ${display}"
      active_with_mtime+=("${mtime}:${display_with_icon}")
    else
      display_with_icon="${display}"
      inactive_with_mtime+=("${mtime}:${display_with_icon}")
    fi
  done

  # Sort each section by mtime (descending - most recent first)
  for entry in ${(On)active_with_mtime}; do
    active_projects+=("${entry#*:}")
  done
  for entry in ${(On)inactive_with_mtime}; do
    inactive_projects+=("${entry#*:}")
  done

  # Combine: active projects first, then inactive (both sorted by mtime)
  all_projects=("${active_projects[@]}" "${inactive_projects[@]}")

  if [[ ${#all_projects[@]} -eq 0 ]]; then
    echo "No projects found in: ${proj_dirs[*]}" >&2
    return 1
  fi

  # If an argument is provided, use it as initial query
  local initial_query="$1"

  # Build preview command
  local preview_script="${_PROJ2_SCRIPT_DIR}/.proj2-preview.sh"
  local preview_cmd="${(qq)preview_script} {} ${(@qq)proj_dirs}"

  # Create temp files for project lists and data
  local active_file=$(mktemp)
  local inactive_file=$(mktemp)
  local project_data_file=$(mktemp)
  trap "rm -f '$active_file' '$inactive_file' '$project_data_file'" EXIT

  printf '%s\n' "${active_projects[@]}" > "$active_file"
  printf '%s\n' "${inactive_projects[@]}" > "$inactive_file"

  # Write project data for git status loader (tab-separated: path, display, mtime, is_active)
  for (( i=1; i <= idx; i++ )); do
    printf '%s\t%s\t%s\t%s\n' "${all_full_paths[$i]}" "${all_displays[$i]}" "${all_mtimes[$i]}" "${all_is_active[$i]}"
  done > "$project_data_file"

  # Build filter command (simple filter without git status)
  local filter_script="${_PROJ2_SCRIPT_DIR}/.proj2-filter.sh"
  local filter_cmd="${(qq)filter_script} {q} ${(qq)active_file} ${(qq)inactive_file}"

  # Build git status loader command (fetches git status and rebuilds list)
  local status_loader_script="${_PROJ2_SCRIPT_DIR}/.proj2-load-status.sh"
  local status_loader_cmd="${(qq)status_loader_script} {q} ${(qq)project_data_file} ${(qq)_PROJ2_SCRIPT_DIR}"

  # Use fzf to select project(s) with multiple actions
  # CTRL-S loads git status for all projects
  # CTRL-P toggles preview pane
  selected=$(fzf \
    --multi \
    --ansi \
    --height=60% \
    --reverse \
    --prompt="Project: " \
    --query="$initial_query" \
    --header="CTRL-S=git status  CTRL-P=preview  CTRL-G=github" \
    --disabled \
    --bind "start:reload:$filter_cmd" \
    --bind "change:reload:$filter_cmd" \
    --bind "ctrl-s:reload:$status_loader_cmd" \
    --bind "ctrl-p:toggle-preview" \
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

  # Helper to look up path from selected item (handles ANSI codes)
  _lookup_path() {
    local item="$1"
    # Try direct lookup first
    if [[ -n "${project_paths[$item]}" ]]; then
      echo "${project_paths[$item]}"
      return
    fi
    # Fallback: strip ANSI and match by project name
    local clean_item=$(echo "$item" | sed $'s/\x1b\\[[0-9;]*m//g')
    clean_item="${clean_item#● }"           # Remove active icon
    clean_item="${clean_item%%  *}"         # Remove git status (after double-space)
    local proj_name="${clean_item##*/}"     # Extract project name
    # Find in proj_dirs
    for pdir in "${proj_dirs[@]}"; do
      if [[ -d "${pdir}/${proj_name}" ]]; then
        echo "${pdir}/${proj_name}"
        return
      fi
    done
  }

  case $action in
    cd)
      # CD to first selected project and attach to/create screen session
      local first="${selected_items[1]}"
      full_path=$(_lookup_path "$first")
      if [[ -d "$full_path" ]]; then
        _proj2_screen_session "$full_path"
      else
        echo "Error: Directory not found for: $first" >&2
        return 1
      fi
      ;;

    github)
      # Open in GitHub (if git repo)
      for item in "${selected_items[@]}"; do
        full_path=$(_lookup_path "$item")
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
