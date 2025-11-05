#### tmux-claude integration plugin
### Integration between Claude Code CLI and tmux terminal multiplexer
### Provides convenient commands and shortcuts for working with Claude Code in tmux
### Uses fzf for interactive selections

script_dir="${0:a:h}"

#### Helper functions

### Check if we're running inside tmux
_tmux_claude_in_tmux() {
  [[ -n "$TMUX" ]]
}

### Check if Claude Code is available
_tmux_claude_check_claude() {
  if ! command -v claude &> /dev/null; then
    rad-red "Error: Claude Code CLI not found. Please install it first."
    return 1
  fi
  return 0
}

#### Core Claude Code launching functions

### claude-split - Split current pane horizontally and start Claude Code
### Usage: claude-split [directory]
claude-split() {
  _tmux_claude_check_claude || return 1

  local target_dir="${1:-.}"

  if _tmux_claude_in_tmux; then
    tmux split-window -h -c "$target_dir" "claude"
  else
    rad-yellow "Not in tmux session. Starting new tmux session..."
    tmux new-session -d -s claude "claude"
    tmux attach-session -t claude
  fi
}

### claude-vsplit - Split current pane vertically and start Claude Code
### Usage: claude-vsplit [directory]
claude-vsplit() {
  _tmux_claude_check_claude || return 1

  local target_dir="${1:-.}"

  if _tmux_claude_in_tmux; then
    tmux split-window -v -c "$target_dir" "claude"
  else
    rad-yellow "Not in tmux session. Starting new tmux session..."
    tmux new-session -d -s claude "claude"
    tmux attach-session -t claude
  fi
}

### claude-window - Create new tmux window and start Claude Code
### Usage: claude-window [directory] [window_name]
claude-window() {
  _tmux_claude_check_claude || return 1

  local target_dir="${1:-.}"
  local window_name="${2:-claude}"

  if _tmux_claude_in_tmux; then
    tmux new-window -n "$window_name" -c "$target_dir" "claude"
  else
    rad-yellow "Not in tmux session. Starting new tmux session..."
    tmux new-session -d -s claude -n "$window_name" -c "$target_dir" "claude"
    tmux attach-session -t claude
  fi
}

### claude-session - Create new tmux session with Claude Code
### Usage: claude-session [session_name] [directory]
claude-session() {
  _tmux_claude_check_claude || return 1

  local session_name="${1:-claude-$(date +%s)}"
  local target_dir="${2:-.}"

  if tmux has-session -t "$session_name" 2>/dev/null; then
    rad-yellow "Session '$session_name' already exists. Attaching..."
    tmux attach-session -t "$session_name"
  else
    rad-green "Creating new tmux session: $session_name"
    tmux new-session -d -s "$session_name" -c "$target_dir" "claude"
    tmux attach-session -t "$session_name"
  fi
}

#### Sending content to Claude Code

### claude-send-keys - Send keys/text to a tmux pane running Claude Code
### Usage: claude-send-keys <pane_id> <text>
### Example: claude-send-keys %2 "help"
claude-send-keys() {
  if [[ $# -lt 2 ]]; then
    rad-red "Usage: claude-send-keys <pane_id> <text>"
    return 1
  fi

  local pane_id="$1"
  shift
  local text="$*"

  # Send the text followed by Enter
  tmux send-keys -t "$pane_id" "$text" C-m
}

### claude-send-file - Send file path to Claude Code in another pane
### Usage: claude-send-file <pane_id> <file_path>
### This sends a message asking Claude to read/analyze the file
claude-send-file() {
  if [[ $# -lt 2 ]]; then
    rad-red "Usage: claude-send-file <pane_id> <file_path>"
    return 1
  fi

  local pane_id="$1"
  local file_path="$2"

  # Resolve to absolute path
  local abs_path="$(cd "$(dirname "$file_path")" && pwd)/$(basename "$file_path")"

  if [[ ! -f "$abs_path" ]]; then
    rad-red "Error: File not found: $file_path"
    return 1
  fi

  rad-green "Sending file to Claude: $abs_path"
  claude-send-keys "$pane_id" "Please analyze this file: $abs_path"
}

### claude-capture - Capture output from a tmux pane and send to Claude Code
### Usage: claude-capture <source_pane_id> <claude_pane_id> [lines]
### Captures the last N lines (default: 50) from source pane and asks Claude about it
claude-capture() {
  if [[ $# -lt 2 ]]; then
    rad-red "Usage: claude-capture <source_pane_id> <claude_pane_id> [lines]"
    return 1
  fi

  local source_pane="$1"
  local claude_pane="$2"
  local lines="${3:-50}"

  # Capture pane content
  local captured=$(tmux capture-pane -p -t "$source_pane" -S -$lines)

  if [[ -z "$captured" ]]; then
    rad-red "Error: Could not capture content from pane $source_pane"
    return 1
  fi

  # Save to temp file
  local temp_file=$(mktemp)
  echo "$captured" > "$temp_file"

  rad-green "Captured $lines lines from pane $source_pane"
  rad-yellow "Sending to Claude in pane $claude_pane..."

  # Send to Claude
  claude-send-keys "$claude_pane" "Please analyze this output: $temp_file"

  # Clean up after a delay (give Claude time to read it)
  (sleep 5 && rm -f "$temp_file") &
}

#### Tmux layout helpers for Claude Code

### claude-layout-sidebyside - Create side-by-side layout with Claude Code
### Left pane: shell, Right pane: Claude Code
claude-layout-sidebyside() {
  _tmux_claude_check_claude || return 1

  local target_dir="${1:-.}"

  if ! _tmux_claude_in_tmux; then
    rad-yellow "Starting new tmux session with side-by-side layout..."
    tmux new-session -d -s claude-dev -c "$target_dir"
    tmux split-window -h -t claude-dev -c "$target_dir" "claude"
    tmux select-pane -t claude-dev:0.0
    tmux attach-session -t claude-dev
  else
    tmux split-window -h -c "$target_dir" "claude"
    tmux select-pane -L
  fi
}

### claude-layout-stack - Create stacked layout with Claude Code
### Top pane: Claude Code (70% height), Bottom pane: shell (30% height)
claude-layout-stack() {
  _tmux_claude_check_claude || return 1

  local target_dir="${1:-.}"

  if ! _tmux_claude_in_tmux; then
    rad-yellow "Starting new tmux session with stacked layout..."
    tmux new-session -d -s claude-dev -c "$target_dir" "claude"
    tmux split-window -v -l 30% -t claude-dev -c "$target_dir"
    tmux select-pane -t claude-dev:0.0
    tmux attach-session -t claude-dev
  else
    tmux split-window -v -l 30% -c "$target_dir"
    tmux select-pane -U
  fi
}

### claude-layout-three - Create three-pane layout
### Left: shell (50%), Top-right: Claude Code (50% of remaining), Bottom-right: logs/output
claude-layout-three() {
  _tmux_claude_check_claude || return 1

  local target_dir="${1:-.}"

  if ! _tmux_claude_in_tmux; then
    rad-yellow "Starting new tmux session with three-pane layout..."
    tmux new-session -d -s claude-dev -c "$target_dir"
    tmux split-window -h -t claude-dev -c "$target_dir" "claude"
    tmux split-window -v -t claude-dev -c "$target_dir"
    tmux select-pane -t claude-dev:0.0
    tmux attach-session -t claude-dev
  else
    # Create right pane with Claude
    tmux split-window -h -c "$target_dir" "claude"
    # Split right pane vertically
    tmux split-window -v -c "$target_dir"
    # Go back to left pane
    tmux select-pane -L
  fi
}

#### FZF-based Interactive Selection Functions

### claude-select-session - Interactive session selector with actions using fzf
### Select and perform actions on tmux sessions
claude-select-session() {
  if ! command -v fzf &> /dev/null; then
    rad-red "Error: fzf is required but not installed"
    return 1
  fi

  local sessions=$(tmux list-sessions -F "#{session_name} | #{session_windows} windows | created: #{session_created_string}" 2>/dev/null)

  if [[ -z "$sessions" ]]; then
    rad-yellow "No tmux sessions found"
    return 1
  fi

  local selected=$(echo "$sessions" | fzf \
    --prompt="Select session > " \
    --header="Enter: attach | Ctrl-K: kill | Ctrl-D: detach others | Esc: cancel" \
    --bind='ctrl-k:execute(tmux kill-session -t {1})+reload(tmux list-sessions -F "#{session_name} | #{session_windows} windows | created: #{session_created_string}" 2>/dev/null)' \
    --bind='ctrl-d:execute(tmux kill-session -a -t {1})' \
    --preview='tmux list-windows -t {1} -F "#{window_index}:#{window_name} - #{pane_current_command}"' \
    --preview-window=right:50%)

  if [[ -n "$selected" ]]; then
    local session_name=$(echo "$selected" | awk '{print $1}')
    if _tmux_claude_in_tmux; then
      tmux switch-client -t "$session_name"
    else
      tmux attach-session -t "$session_name"
    fi
  fi
}

### claude-select-pane - Interactive pane selector with actions using fzf
### Select and perform actions on tmux panes
claude-select-pane() {
  if ! command -v fzf &> /dev/null; then
    rad-red "Error: fzf is required but not installed"
    return 1
  fi

  if ! _tmux_claude_in_tmux; then
    rad-red "Error: Not in a tmux session"
    return 1
  fi

  local panes=$(tmux list-panes -a -F "#{pane_id} | #{session_name}:#{window_index}.#{pane_index} | #{pane_current_command} | #{pane_current_path}")

  if [[ -z "$panes" ]]; then
    rad-yellow "No tmux panes found"
    return 1
  fi

  local selected=$(echo "$panes" | fzf \
    --prompt="Select pane > " \
    --header="Enter: switch | Ctrl-C: capture | Ctrl-K: kill | Ctrl-Y: copy pane-id | Esc: cancel" \
    --bind="ctrl-c:execute(echo {1} | xargs tmux capture-pane -p -t | less)" \
    --bind="ctrl-k:execute(tmux kill-pane -t {1})+reload(tmux list-panes -a -F '#{pane_id} | #{session_name}:#{window_index}.#{pane_index} | #{pane_current_command} | #{pane_current_path}')" \
    --bind="ctrl-y:execute-silent(echo {1} | tr -d '\n' | xclip -selection clipboard)+abort" \
    --preview='tmux capture-pane -p -t {1}' \
    --preview-window=right:60%)

  if [[ -n "$selected" ]]; then
    local pane_id=$(echo "$selected" | awk '{print $1}')
    tmux select-pane -t "$pane_id"
  fi
}

### claude-select-window - Interactive window selector using fzf
### Select and switch to tmux windows
claude-select-window() {
  if ! command -v fzf &> /dev/null; then
    rad-red "Error: fzf is required but not installed"
    return 1
  fi

  if ! _tmux_claude_in_tmux; then
    rad-red "Error: Not in a tmux session"
    return 1
  fi

  local windows=$(tmux list-windows -a -F "#{session_name}:#{window_index} | #{window_name} | #{window_panes} panes | #{pane_current_command}")

  if [[ -z "$windows" ]]; then
    rad-yellow "No tmux windows found"
    return 1
  fi

  local selected=$(echo "$windows" | fzf \
    --prompt="Select window > " \
    --header="Enter: switch | Ctrl-K: kill | Esc: cancel" \
    --bind="ctrl-k:execute(tmux kill-window -t {1})+reload(tmux list-windows -a -F '#{session_name}:#{window_index} | #{window_name} | #{window_panes} panes | #{pane_current_command}')" \
    --preview='tmux list-panes -t {1} -F "#{pane_index}: #{pane_current_command} - #{pane_current_path}"' \
    --preview-window=right:50%)

  if [[ -n "$selected" ]]; then
    local window_target=$(echo "$selected" | awk '{print $1}')
    tmux select-window -t "$window_target"
  fi
}

### claude-send-to-pane - Interactive pane selector to send text/commands
### Select a pane and send text to it
claude-send-to-pane() {
  if ! command -v fzf &> /dev/null; then
    rad-red "Error: fzf is required but not installed"
    return 1
  fi

  if ! _tmux_claude_in_tmux; then
    rad-red "Error: Not in a tmux session"
    return 1
  fi

  local panes=$(tmux list-panes -a -F "#{pane_id} | #{session_name}:#{window_index}.#{pane_index} | #{pane_current_command} | #{pane_current_path}")

  if [[ -z "$panes" ]]; then
    rad-yellow "No tmux panes found"
    return 1
  fi

  local selected=$(echo "$panes" | fzf \
    --prompt="Select target pane > " \
    --header="Select pane to send text to" \
    --preview='tmux capture-pane -p -t {1}' \
    --preview-window=right:60%)

  if [[ -n "$selected" ]]; then
    local pane_id=$(echo "$selected" | awk '{print $1}')

    # Prompt for text to send
    echo -n "Enter text to send (press Enter when done): "
    read text_to_send

    if [[ -n "$text_to_send" ]]; then
      tmux send-keys -t "$pane_id" "$text_to_send" C-m
      rad-green "Sent to pane $pane_id: $text_to_send"
    fi
  fi
}

#### Utility functions

### claude-list-panes - List all tmux panes with their IDs
### Useful for finding pane IDs to send commands to
claude-list-panes() {
  if ! _tmux_claude_in_tmux; then
    rad-red "Error: Not in a tmux session"
    return 1
  fi

  rad-yellow "Current tmux panes:"
  tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index} - #{pane_current_command} - #{pane_current_path}"
}

### claude-find-pane - Find panes running Claude Code
### Returns pane IDs of panes running claude command
claude-find-pane() {
  if ! _tmux_claude_in_tmux; then
    rad-red "Error: Not in a tmux session"
    return 1
  fi

  local claude_panes=$(tmux list-panes -a -F "#{pane_id} #{pane_current_command}" | grep -i claude | awk '{print $1}')

  if [[ -z "$claude_panes" ]]; then
    rad-yellow "No panes running Claude Code found"
    return 1
  else
    rad-green "Found Claude Code panes:"
    echo "$claude_panes"
    return 0
  fi
}

### claude-goto - Quick jump to a pane running Claude Code
### If multiple Claude panes exist, uses fzf/zaw to select
claude-goto() {
  if ! _tmux_claude_in_tmux; then
    rad-red "Error: Not in a tmux session"
    return 1
  fi

  local claude_panes=$(tmux list-panes -a -F "#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_current_path}" | grep -E "claude|node.*claude")

  if [[ -z "$claude_panes" ]]; then
    rad-yellow "No Claude Code panes found. Start one with: claude-split"
    return 1
  fi

  local pane_count=$(echo "$claude_panes" | wc -l)

  if [[ $pane_count -eq 1 ]]; then
    local pane_id=$(echo "$claude_panes" | awk '{print $1}')
    tmux select-pane -t "$pane_id"
  else
    # Multiple panes - let user choose
    if command -v fzf &> /dev/null; then
      local selected=$(echo "$claude_panes" | fzf --prompt="Select Claude pane: ")
      if [[ -n "$selected" ]]; then
        local pane_id=$(echo "$selected" | awk '{print $1}')
        tmux select-pane -t "$pane_id"
      fi
    else
      rad-yellow "Multiple Claude panes found. Use Zaw integration (^[P) or install fzf for selection."
      echo "$claude_panes"
    fi
  fi
}

#### Aliases

# Starting Claude
alias tc='claude-split'
alias tcv='claude-vsplit'
alias tcw='claude-window'
alias tcs='claude-session'

# Layouts
alias tcls='claude-layout-sidebyside'
alias tclk='claude-layout-stack'
alias tcl3='claude-layout-three'

# Utilities
alias tcl='claude-list-panes'
alias tcf='claude-find-pane'
alias tcg='claude-goto'

# FZF interactive selectors
alias tss='claude-select-session'
alias tsp='claude-select-pane'
alias tsw='claude-select-window'
alias tcsp='claude-send-to-pane'

#### Help function

### tmux-claude-help - Show help for tmux-claude integration commands
tmux-claude-help() {
  cat << 'EOF'
Tmux-Claude Integration Plugin
================================

Starting Claude Code:
  claude-split [dir]              Split pane horizontally and start Claude (alias: tc)
  claude-vsplit [dir]             Split pane vertically and start Claude (alias: tcv)
  claude-window [dir] [name]      Create new window with Claude (alias: tcw)
  claude-session [name] [dir]     Create new session with Claude (alias: tcs)

Layouts:
  claude-layout-sidebyside [dir]  Side-by-side: shell | Claude (alias: tcls)
  claude-layout-stack [dir]       Stacked: Claude (top) | shell (bottom) (alias: tclk)
  claude-layout-three [dir]       Three panes: shell | Claude + output (alias: tcl3)

Sending Content to Claude:
  claude-send-keys <pane> <text>  Send text to Claude pane
  claude-send-file <pane> <file>  Send file path to Claude
  claude-capture <src> <dst> [n]  Capture N lines from src pane, send to Claude

FZF Interactive Selectors (requires fzf):
  claude-select-session           Interactive session selector (alias: tss)
    - Enter: attach/switch to session
    - Ctrl-K: kill session
    - Ctrl-D: kill all other sessions
    - Preview: show windows in session

  claude-select-pane              Interactive pane selector (alias: tsp)
    - Enter: switch to pane
    - Ctrl-C: capture and view pane output
    - Ctrl-K: kill pane
    - Ctrl-Y: copy pane ID to clipboard
    - Preview: show pane content

  claude-select-window            Interactive window selector (alias: tsw)
    - Enter: switch to window
    - Ctrl-K: kill window
    - Preview: show panes in window

  claude-send-to-pane             Select pane and send text (alias: tcsp)

Navigation & Utilities:
  claude-list-panes               List all tmux panes with IDs (alias: tcl)
  claude-find-pane                Find panes running Claude Code (alias: tcf)
  claude-goto                     Jump to Claude Code pane (alias: tcg)

Examples:
  tc                              # Split and start Claude in current directory
  tc ~/projects                   # Split and start Claude in ~/projects
  tcw myproject                   # New window named 'myproject' with Claude
  tcls                            # Create side-by-side layout
  tss                             # Interactive session selector
  tsp                             # Interactive pane selector
  tcsp                            # Send text to selected pane
  claude-send-file %2 file.txt    # Send file.txt to pane %2 running Claude
  tcg                             # Jump to Claude pane

For more help: tmux-claude-help
EOF
}

alias tc-help='tmux-claude-help'
