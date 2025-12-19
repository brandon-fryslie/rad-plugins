#!/usr/bin/env zsh
# workspace-actions.zsh - Contextual workspace action menu
#
# Provides a unified opt+w key binding that shows context-aware fzf menu
# of available actions based on current directory, git repo, tmux session, etc.
#
# Dependencies:
#   - fzf (required)
#   - git (optional, for git actions)
#   - tmux (optional, for tmux actions)
#   - docker (optional, for docker actions)
#
# Usage:
#   Press opt+w to open workspace actions menu
#   Or call directly: workspace-actions

# Global action registry (associative array)
# Format: WA_ACTIONS[id]="label|description|contexts|handler"
typeset -gA WA_ACTIONS

#
# Core Functions
#

# Main entry point - displays context-aware action menu
workspace-actions() {
  # Check for fzf dependency
  if ! command -v fzf &>/dev/null; then
    echo "Error: workspace-actions requires fzf. Install with: brew install fzf" >&2
    return 1
  fi

  local context=$(_wa_detect_context)
  local -a actions=($(_wa_get_actions_for_context "$context"))

  # Check if we have any actions
  if [[ ${#actions} -eq 0 ]]; then
    echo "No actions available for current context" >&2
    return 1
  fi

  # Show fzf menu with actions
  local selected=$(printf '%s\n' "${actions[@]}" | \
    fzf --ansi \
        --height=60% \
        --reverse \
        --prompt="Workspace > " \
        --header="$(_wa_context_header "$context")" \
        --preview-window=right:40%:wrap)

  # Handle cancellation
  [[ -z $selected ]] && return 0

  # Extract action ID (first field)
  local action_id=$(echo "$selected" | awk '{print $1}')

  # Execute the selected action
  _wa_execute_action "$action_id" "$context"
}

# Detect current context and return comma-separated string
# Returns: "git,tmux,docker" or empty string
_wa_detect_context() {
  local ctx=""

  # Git repo detection
  if git rev-parse --git-dir &>/dev/null; then
    ctx+="git,"
  fi

  # Tmux session detection
  if [[ -n "$TMUX" ]]; then
    ctx+="tmux,"
  fi

  # Docker availability
  if command -v docker &>/dev/null; then
    ctx+="docker,"
  fi

  # Remove trailing comma
  echo "${ctx%,}"
}

# Generate context header for fzf display
# Parameters:
#   $1 - context string (e.g., "git,tmux")
_wa_context_header() {
  local context="$1"
  local header="Workspace Actions"
  local -a parts=()

  # Add git repo name if in git context
  if [[ "$context" == *"git"* ]]; then
    local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
    [[ -n "$repo_name" ]] && parts+=("git: $repo_name")
  fi

  # Add tmux session name if in tmux context
  if [[ "$context" == *"tmux"* ]]; then
    local session_name=$(tmux display-message -p '#S' 2>/dev/null)
    [[ -n "$session_name" ]] && parts+=("tmux: $session_name")
  fi

  # Add docker status if available
  if [[ "$context" == *"docker"* ]]; then
    parts+=("docker: available")
  fi

  # Construct final header
  if [[ ${#parts} -gt 0 ]]; then
    header+=" (${(j:, :)parts})"
  fi

  echo "$header"
}

# Check if current context matches required contexts
# Parameters:
#   $1 - current context string (e.g., "git,tmux")
#   $2 - required contexts (e.g., "git" or "git,tmux" or "all")
# Returns: 0 if match, 1 if no match
_wa_context_matches() {
  local current="$1"
  local required="$2"

  # "all" context always matches
  [[ "$required" == "all" ]] && return 0

  # Empty current context only matches "all"
  [[ -z "$current" ]] && return 1

  # Check if any required context is present in current context
  local -a req_parts=(${(s:,:)required})
  local req
  for req in "${req_parts[@]}"; do
    if [[ "$current" == *"$req"* ]]; then
      return 0
    fi
  done

  return 1
}

# Register an action in the global registry
# Parameters:
#   $1 - action ID (short, unique identifier)
#   $2 - label (display name)
#   $3 - description (help text)
#   $4 - contexts (comma-separated or "all")
#   $5 - handler function name
_wa_register_action() {
  local id="$1"
  local label="$2"
  local description="$3"
  local contexts="$4"
  local handler="$5"

  WA_ACTIONS[$id]="$label|$description|$contexts|$handler"
}

# Get actions matching current context
# Parameters:
#   $1 - current context string
# Returns: array of formatted action strings for fzf
_wa_get_actions_for_context() {
  local current_context="$1"
  local -a matching_actions

  for id in ${(k)WA_ACTIONS}; do
    local entry="${WA_ACTIONS[$id]}"
    local label=$(echo "$entry" | cut -d'|' -f1)
    local description=$(echo "$entry" | cut -d'|' -f2)
    local contexts=$(echo "$entry" | cut -d'|' -f3)
    local handler=$(echo "$entry" | cut -d'|' -f4)

    # Check if handler exists
    if ! typeset -f "$handler" &>/dev/null; then
      echo "Warning: handler '$handler' not found for action '$id'" >&2
      continue
    fi

    # Check if context matches
    if _wa_context_matches "$current_context" "$contexts"; then
      # Format: "id  label  description"
      matching_actions+=("$id  $label  $description")
    fi
  done

  echo "${matching_actions[@]}"
}

# Execute selected action
# Parameters:
#   $1 - action ID
#   $2 - current context
_wa_execute_action() {
  local action_id="$1"
  local context="$2"
  local entry="${WA_ACTIONS[$action_id]}"

  if [[ -z "$entry" ]]; then
    echo "Error: unknown action '$action_id'" >&2
    return 1
  fi

  local handler=$(echo "$entry" | cut -d'|' -f4)

  # Check if handler exists
  if ! typeset -f "$handler" &>/dev/null; then
    echo "Error: handler function '$handler' not found" >&2
    return 1
  fi

  # Call handler function
  "$handler"
}

#
# Action Handlers
#

# Wrapper for proj2 project switcher
_wa_switch_project() {
  proj2
}

# Wrapper for git status zaw
# Note: zaw-rad-git-status is a regular function, not a widget
_wa_git_status() {
  zaw-rad-git-status
}

# Wrapper for git branch zaw
# Note: zaw-git-branch is a ZLE widget, so we need to invoke it properly
_wa_git_branch() {
  # Invoke the widget using zle command
  # This works because workspace-actions itself is a widget (registered at end of file)
  zle zaw-git-branch
}

# Wrapper for executable finder
# Note: zaw-rad-exec-find is a ZLE widget, so we need to invoke it properly
_wa_find_executable() {
  # Invoke the widget using zle command
  # This works because workspace-actions itself is a widget (registered at end of file)
  zle zaw-rad-exec-find
}

# Tmux session switcher using fzf
_wa_tmux_sessions() {
  if ! command -v tmux &>/dev/null; then
    echo "Error: tmux not available" >&2
    return 1
  fi

  local session=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | \
    fzf --prompt="tmux session > " \
        --height=40% \
        --reverse)

  if [[ -n "$session" ]]; then
    tmux switch-client -t "$session" 2>/dev/null || \
      echo "Switched to session: $session (use 'tmux attach -t $session' to attach)"
  fi
}

#
# Action Registration
#

# Register core actions on plugin load
_wa_register_action "proj" "Switch Project" \
  "Navigate to another project" "all" "_wa_switch_project"

_wa_register_action "gst" "Git Status" \
  "View and stage/unstage files" "git" "_wa_git_status"

_wa_register_action "gbr" "Git Branch" \
  "Switch or create branches" "git" "_wa_git_branch"

_wa_register_action "exec" "Find Executable" \
  "Search for runnable scripts" "all" "_wa_find_executable"

_wa_register_action "tses" "tmux Sessions" \
  "Switch to another tmux session" "tmux" "_wa_tmux_sessions"

# Register workspace-actions as a ZLE widget so it can invoke other widgets
zle -N workspace-actions
