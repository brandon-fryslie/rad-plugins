# proj2z (p2z) - cd to a project directory using fzf
# Supports multiple project directories via PROJECTS_DIRS (array)
# or single directory via PROJECTS_DIR (backward compatibility)
#
# Navigating to a project also brings up `claude remote-control --spawn worktree`
# for it, as a detached window in one shared tmux session (PROJ2Z_RC_SESSION,
# default "p2z/remote-control") so it never occupies a terminal. p2rc goes there
# to read a server's log or restart it. A project must have been trusted by
# running `claude` in it once, or its server sits on the trust prompt in its
# window.

# Get the directory where this script is located
typeset -g _PROJ2Z_SCRIPT_DIR="${${(%):-%x}:A:h}"

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
_proj2z_git_status() {
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

# Name of the one tmux session that hosts every `claude remote-control` server.
# The `/` is load-bearing: _proj2z_validate_project_name rejects that character in
# project names, so no project's basename can equal this session's name. Without
# that disjointness a project called `remote-control` is silently redirected into
# this session instead of getting its own - or, if its session already exists, has
# a server window injected into it.
# [LAW:one-source-of-truth] Read at call time (never assigned at load) so the value
# a caller or a test exports is the only name in play, with no load-order coupling.
_proj2z_rc_session_name() {
  echo "${PROJ2Z_RC_SESSION:-p2z/remote-control}"
}

# tmux builds every session around a first window, so the remote-control session
# has one that hosts no server. It is where `p2rc` lands a human.
typeset -g _PROJ2Z_RC_HOME_WINDOW='shell'

# The tmux pane option every remote-control pane carries: the full path of the
# project its server serves. [LAW:one-source-of-truth] This stamp is the identity.
# A basename cannot serve as one - two projects in different PROJECTS_DIRS
# routinely share theirs - and neither can a window: `p2rc` invites a human into
# this session, and the pane they split off would answer for the window. What runs
# a server is a pane, so a pane is what carries the name of what it is running.
typeset -g _PROJ2Z_RC_STAMP='@proj2z_project'

# This project's remote-control pane: whether it is absent, dead, or alive, and
# which pane it is. Always prints "<state>\t<pane_id>"; absent carries no id.
# A pane whose server died still exists, so reporting mere presence would read a
# crashed server as a running one and never bring it back.
_proj2z_rc_state() {
  local rc_session="$1"
  local project_path="$2"

  local -a rows
  local fmt="#{pane_dead}"$'\t'"#{pane_id}"$'\t'"#{${_PROJ2Z_RC_STAMP}}"
  # A missing session makes this fail, which is the same answer as no pane.
  rows=(${(f)"$(tmux list-panes -s -t "=${rc_session}" -F "$fmt" 2>/dev/null)"}) \
    || { print -r -- $'absent\t'; return 0 }

  # Matched in zsh rather than through a tmux -f filter, so a project path
  # containing tmux format characters cannot change what gets matched.
  local row pane_id
  for row in "${rows[@]}"; do
    # The maintenance window, and any pane a human split off, carry no stamp -
    # so neither can be mistaken for a project's server.
    [[ "${row#*$'\t'*$'\t'}" == "$project_path" ]] || continue
    pane_id="${${row#*$'\t'}%%$'\t'*}"
    [[ "${row%%$'\t'*}" == 1 ]] && { print -r -- $'dead\t'"$pane_id"; return 0 }
    print -r -- $'alive\t'"$pane_id"
    return 0
  done

  print -r -- $'absent\t'
}

# Bring up this project's `claude remote-control` server if it is not already
# running, as a detached window in the shared remote-control session. Converges:
# calling it on every navigation is a no-op once the server is up, and revives it
# if it died. Assumes tmux - its one caller checks that first.
_proj2z_ensure_remote_control() {
  local project_path="$1"
  local rc_session="$(_proj2z_rc_session_name)"
  local window_name="${project_path:t}"

  # [LAW:parse-dont-validate] Keep the path this resolves to rather than a boolean:
  # the pane runs under the tmux server's environment, not this shell's, so a
  # `claude` reachable only from here would exit 127 out of sight and leave the
  # function reporting a server it never managed to start.
  local claude_bin
  claude_bin="$(command -v claude)" || {
    echo "Warning: claude is not installed; no remote-control session for $window_name" >&2
    return 0
  }

  local rc_reply="$(_proj2z_rc_state "$rc_session" "$project_path")"
  local rc_state="${rc_reply%%$'\t'*}"
  local pane_id="${rc_reply#*$'\t'}"

  [[ "$rc_state" == alive ]] && return 0

  if ! tmux has-session -t "=${rc_session}" 2>/dev/null; then
    tmux new-session -d -s "$rc_session" -c "$HOME" -n "$_PROJ2Z_RC_HOME_WINDOW" || {
      echo "Error: could not create tmux session: $rc_session" >&2
      return 1
    }
  fi

  # A pane born running the server can die before `remain-on-exit` reaches it,
  # taking the startup error with it. [LAW:no-ambient-temporal-coupling] Open it
  # empty - nothing to exit - configure it while it is provably stable, and only
  # then respawn it into the server, with the option already in force.
  if [[ "$rc_state" == absent ]]; then
    pane_id="$(tmux new-window -d -P -F '#{pane_id}' \
      -t "=${rc_session}" -c "$project_path" -n "$window_name")" || {
      echo "Error: could not open remote-control window for: $project_path" >&2
      return 1
    }

    # [LAW:no-silent-failure] A server that dies on startup (untrusted workspace, an
    # inference-only token) leaves its error on screen instead of closing the pane.
    tmux set-option -p -t "$pane_id" remain-on-exit on || {
      echo "Error: could not set remain-on-exit on pane: $pane_id" >&2
      return 1
    }
  fi

  # tmux hands the command to a shell, so both words are quoted for that shell
  # rather than passed as argv - paths and project names may contain spaces.
  local rc_command="${(q)claude_bin} remote-control --spawn worktree --name ${(q)window_name}"

  # [LAW:dataflow-not-control-flow] The one operation a missing server and a dead one
  # both arrive at: a configured pane, respawned into the server it should run.
  tmux respawn-pane -k -t "$pane_id" "$rc_command" || {
    echo "Error: could not start remote control for: $project_path" >&2
    return 1
  }

  # [LAW:parse-dont-validate] Written last, so the stamp is proof that every step
  # above succeeded. A pane configured only halfway carries none, and so is never
  # read back as a live server that no navigation will ever revive.
  tmux set-option -p -t "$pane_id" "$_PROJ2Z_RC_STAMP" "$project_path" || {
    echo "Error: could not record the project on pane: $pane_id" >&2
    return 1
  }

  echo "Remote control: ${rc_session}:${window_name} (p2rc to inspect)"
}

# Go to the shared remote-control session to inspect, restart, or kill servers.
proj2z_remote_control() {
  local rc_session="$(_proj2z_rc_session_name)"

  if ! command -v tmux &> /dev/null; then
    echo "Error: tmux is not installed." >&2
    return 1
  fi

  if ! tmux has-session -t "=${rc_session}" 2>/dev/null; then
    echo "No remote-control session yet - p2z into a project to start one." >&2
    return 1
  fi

  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "=${rc_session}"
  else
    tmux attach-session -t "=${rc_session}"
  fi
}

# Create or attach to tmux session for project
_proj2z_screen_session() {
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

  # Before the attach below, which blocks until detach when we start outside tmux.
  # [LAW:no-ambient-temporal-coupling] Ordering is the point, not an accident of
  # where the line landed. Unconditional: it converges rather than toggling.
  _proj2z_ensure_remote_control "$project_path"

  # Helper to attach/switch to session (uses switch-client if inside tmux)
  _proj2z_goto_session() {
    # A bare tmux target prefix-matches, so `rad` would land in `rad-plugins`.
    # The `=` makes it the session named exactly this and no other.
    local target="=$1"
    if (( inside_tmux )); then
      tmux switch-client -t "$target"
    else
      tmux attach-session -t "$target"
    fi
  }

  # Check if session already exists - exactly this one, not one it prefixes
  if tmux has-session -t "=$session_name" 2>/dev/null; then
    echo "Switching to tmux session: $session_name"
    _proj2z_goto_session "$session_name"
  else
    echo "Creating new tmux session: $session_name"

    # Create new tmux session with project directory as start directory
    # First window: run clod if available
    if (( $+commands[clod] )); then
      tmux new-session -s "$session_name" -c "$project_path" -d -n "clod" clod
      # Second window: regular shell (no command specified = use default shell)
      tmux new-window -t "$session_name" -c "$project_path" -n "shell"
      # Select the shell window
      tmux select-window -t "=$session_name:=shell"
      # Attach/switch to the session
      _proj2z_goto_session "$session_name"
    else
      # No clod available - behavior differs if inside tmux or not
      if (( inside_tmux )); then
        # Create detached, then switch
        tmux new-session -s "$session_name" -c "$project_path" -d
        tmux switch-client -t "=$session_name"
      else
        # Create and attach directly
        tmux new-session -s "$session_name" -c "$project_path"
      fi
    fi
  fi
}

# Get project directories (dynamically checks variables each time)
_proj2z_get_dirs() {
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

# Validate project name for creation
# Returns 0 if valid, 1 if invalid (with error message to stderr)
_proj2z_validate_project_name() {
  local name="$1"

  # Check empty
  if [[ -z "$name" ]]; then
    echo "Error: Project name cannot be empty" >&2
    return 1
  fi

  # Check whitespace only
  if [[ "$name" == *[^[:space:]]* ]]; then
    : # Contains non-whitespace, this is good
  else
    echo "Error: Project name cannot be only whitespace" >&2
    return 1
  fi

  # Check for /
  if [[ "$name" == */* ]]; then
    echo "Error: Project name cannot contain '/'" >&2
    return 1
  fi

  # Check leading .
  if [[ "$name" == .* ]]; then
    echo "Error: Project name cannot start with '.'" >&2
    return 1
  fi

  return 0
}

# Select project directory from PROJECTS_DIRS
# Returns the selected directory or the first/only directory
_proj2z_select_project_dir() {
  local -a proj_dirs
  proj_dirs=(${(z)$(_proj2z_get_dirs)})

  if [[ ${#proj_dirs[@]} -eq 0 ]]; then
    echo "Error: No project directories configured" >&2
    return 1
  elif [[ ${#proj_dirs[@]} -eq 1 ]]; then
    echo "${proj_dirs[1]}"
    return 0
  fi

  # Multiple directories - use fzf
  local selected
  selected=$(printf '%s\n' "${proj_dirs[@]}" | fzf --prompt="Project directory: " --height=10 --reverse)

  if [[ -z "$selected" ]]; then
    return 1  # User cancelled
  fi

  echo "$selected"
  return 0
}

# Create a new project directory with git init and README
# Arguments: project_dir project_name
# Returns 0 on success, 1 on failure
_proj2z_create_project() {
  local project_dir="$1"
  local project_name="$2"
  local full_path="${project_dir}/${project_name}"

  # Check if already exists
  if [[ -d "$full_path" ]]; then
    echo "Error: Project directory already exists: $full_path" >&2
    return 1
  fi

  # Create directory
  if ! mkdir -p "$full_path"; then
    echo "Error: Failed to create directory: $full_path" >&2
    return 1
  fi

  # Initialize git (check if git is available first)
  if command -v git &> /dev/null; then
    if ! (cd "$full_path" && git init) &>/dev/null; then
      echo "Error: Failed to initialize git repository" >&2
      rm -rf "$full_path"  # Cleanup
      return 1
    fi

    # Create README
    if ! echo "# ${project_name}" > "${full_path}/README.md"; then
      echo "Error: Failed to create README.md" >&2
      rm -rf "$full_path"  # Cleanup
      return 1
    fi

    # Make initial commit
    if ! (cd "$full_path" && git add README.md && git commit -m "Initial commit: Add README") &>/dev/null; then
      echo "Warning: Failed to create initial commit" >&2
      # Don't fail completely - project is still usable
    fi
  else
    echo "Warning: git not found, skipping repository initialization" >&2
    # Still create README
    if ! echo "# ${project_name}" > "${full_path}/README.md"; then
      echo "Error: Failed to create README.md" >&2
      rm -rf "$full_path"  # Cleanup
      return 1
    fi
  fi

  echo "$full_path"  # Return the path for use by caller
  return 0
}

# Handle non-interactive project creation: p2 --new <name> [--project-dir=N]
_proj2z_handle_new_project_noninteractive() {
  local project_name="$1"
  shift  # Remove project name from args

  # Parse --project-dir option (default to 1 = first directory)
  local project_dir_idx=1
  for arg in "$@"; do
    if [[ "$arg" =~ ^--project-dir=([0-9]+)$ ]]; then
      project_dir_idx="${match[1]}"
    fi
  done

  # Validate name
  if [[ -z "$project_name" ]]; then
    echo "Error: Project name required" >&2
    echo "Usage: p2 --new <project-name> [--project-dir=N]" >&2
    return 1
  fi

  _proj2z_validate_project_name "$project_name" || return 1

  # Get project directories
  local -a proj_dirs
  proj_dirs=(${(z)$(_proj2z_get_dirs)})

  # Validate index
  if (( project_dir_idx < 1 || project_dir_idx > ${#proj_dirs[@]} )); then
    echo "Error: --project-dir=$project_dir_idx out of range (1-${#proj_dirs[@]})" >&2
    return 1
  fi

  local target_dir="${proj_dirs[$project_dir_idx]}"

  # Create project
  local full_path
  full_path=$(_proj2z_create_project "$target_dir" "$project_name") || return 1

  echo "Created new project: $full_path"
  return 0
}

# Handle interactive project creation: p2 --new
_proj2z_handle_new_project_interactive() {
  local -a proj_dirs
  proj_dirs=(${(z)$(_proj2z_get_dirs)})

  if [[ ${#proj_dirs[@]} -eq 0 ]]; then
    echo "Error: No project directories configured" >&2
    return 1
  fi

  local selected_dir="${proj_dirs[1]}"
  local project_name=""

  # Step 1: Select directory (if multiple)
  if [[ ${#proj_dirs[@]} -gt 1 ]]; then
    echo "proj2z new: Select project directory"
    selected_dir=$(_proj2z_select_project_dir) || {
      echo "Cancelled"
      return 1
    }
  fi

  # Step 2: Prompt for name
  echo "proj2z new: Please choose a project name"
  echo "creating in project dir: ${selected_dir}"

  # Retry loop for invalid names
  while true; do
    echo -n "> "
    read -r project_name

    # Check if user cancelled (empty input)
    if [[ -z "$project_name" ]]; then
      echo "Cancelled"
      return 1
    fi

    # Validate name
    if _proj2z_validate_project_name "$project_name"; then
      break  # Valid name, proceed
    fi
    # Invalid - loop will show prompt again
    echo "Please try again:"
  done

  # Create project
  local full_path
  full_path=$(_proj2z_create_project "$selected_dir" "$project_name") || return 1

  echo "Created new project: $full_path"

  # Navigate to project
  _proj2z_screen_session "$full_path"

  echo "Done!"
  return 0
}

function proj2z {
  # Argument parsing - check for --new flag
  if [[ $1 == "--new" ]]; then
    shift  # Remove --new from args

    # Determine interactive vs non-interactive
    if [[ -z "$1" ]]; then
      # Interactive mode: p2 --new
      _proj2z_handle_new_project_interactive
      return $?
    else
      # Non-interactive mode: p2 --new <name> [--project-dir=N]
      _proj2z_handle_new_project_noninteractive "$@"
      return $?
    fi
  fi

  local selected project_name proj_dir parent_dir action display display_with_icon
  local -a proj_dirs all_projects selected_items active_projects inactive_projects
  local full_path

  # Check if fzf is available
  if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is not installed. Please install fzf to use proj2z." >&2
    return 1
  fi

  # Get current project directories
  proj_dirs=(${(z)$(_proj2z_get_dirs)})

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
  local preview_script="${_PROJ2Z_SCRIPT_DIR}/.proj2z-preview.sh"
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
  local filter_script="${_PROJ2Z_SCRIPT_DIR}/.proj2z-filter.sh"
  local filter_cmd="${(qq)filter_script} {q} ${(qq)active_file} ${(qq)inactive_file}"

  # Build git status loader command (fetches git status and rebuilds list)
  local status_loader_script="${_PROJ2Z_SCRIPT_DIR}/.proj2z-load-status.sh"
  local status_loader_cmd="${(qq)status_loader_script} {q} ${(qq)project_data_file} ${(qq)_PROJ2Z_SCRIPT_DIR}"

  # Use fzf to select project(s) with multiple actions
  # CTRL-S loads git status for all projects
  # CTRL-P toggles preview pane
  # --expect=ctrl-g: fzf prefixes output with the triggering key so action is
  # determined from structured output, not side-channel temp files
  local fzf_output
  fzf_output=$(fzf \
    --multi \
    --ansi \
    --height=60% \
    --reverse \
    --prompt="Project: " \
    --query="$initial_query" \
    --header="CTRL-S=git status  CTRL-P=preview  CTRL-G=github" \
    --disabled \
    --expect=ctrl-g \
    --bind "start:reload:$filter_cmd" \
    --bind "change:reload:$filter_cmd" \
    --bind "ctrl-s:reload:$status_loader_cmd" \
    --bind "ctrl-p:toggle-preview" \
    --preview="$preview_cmd" \
    --preview-window=right:50%:wrap \
    --select-1 \
    --exit-0)

  local -a fzf_lines
  fzf_lines=("${(@f)fzf_output}")
  local key="${fzf_lines[1]}"
  selected="${(j:\n:)fzf_lines[2,-1]}"

  if [[ $key == "ctrl-g" && -n $selected ]]; then
    action="github"
  elif [[ -n $selected ]]; then
    action="cd"
  else
    return 1
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
        _proj2z_screen_session "$full_path"
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

# Create alias 'p2z' for quick access
alias p2z='proj2z'

# Create alias 'p2rc' to reach the session hosting the remote-control servers
alias p2rc='proj2z_remote_control'
