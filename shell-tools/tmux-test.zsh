# Test function for tmux with proj2 workflow
# Source this file to test: source ~/.zgenom/sources/brandon-fryslie/rad-plugins/___/shell-tools/tmux-test.zsh

tmux-test() {
  # Reload this function to pick up latest changes
  local script_dir="${${(%):-%x}:a:h}"
  source "$script_dir/tmux-test.zsh"

  local project_path="${1:-$PWD}"
  local session_name="test-$(basename $project_path)"

  # Check if tmux is installed
  if ! command -v tmux &> /dev/null; then
    echo "Error: tmux not installed. Install with: brew install tmux"
    return 1
  fi

  # Kill ALL test sessions (clean slate for testing)
  echo "Cleaning up old test sessions..."
  local test_sessions=$(tmux list-sessions 2>/dev/null | grep '^test-' | cut -d: -f1)
  if [[ -n "$test_sessions" ]]; then
    echo "$test_sessions" | while read -r session; do
      echo "  Killing session: $session"
      tmux kill-session -t "$session" 2>/dev/null
    done
  fi

  # Reload tmux config to pick up latest changes
  echo "Reloading tmux config..."
  tmux source-file ~/.tmux.conf 2>/dev/null || true

  # Clear any stale help pane IDs
  tmux set -g @help_pane_id "" 2>/dev/null || true

  # Now create fresh session
  echo "Creating fresh tmux session: $session_name"
  echo "  - Left pane: runs 'clod'"
  echo "  - Right pane: normal shell"
  echo ""

  # Check if session exists (shouldn't after cleanup, but just in case)
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "Attaching to existing session: $session_name"
    tmux attach-session -t "$session_name"
  else
    echo "Creating new tmux session: $session_name"
    echo "This will:"
    echo "  - Create 2 vertical panes"
    echo "  - Left pane: runs 'clod'"
    echo "  - Right pane: normal shell"
    echo ""

    # Create session with initial window
    tmux new-session -d -s "$session_name" -c "$project_path"

    # Split window vertically (left/right)
    tmux split-window -h -t "$session_name" -c "$project_path"

    # Left pane (0): run clod
    tmux send-keys -t "$session_name:1.0" "cd '$project_path' && clod" C-m

    # Right pane (1): just cd to project (ready for commands)
    tmux send-keys -t "$session_name:1.1" "cd '$project_path'" C-m

    # Select right pane (so you start in the terminal, not clod)
    tmux select-pane -t "$session_name:1.1"

    # Attach to the session
    tmux attach-session -t "$session_name"
  fi
}

# Quick reference function
tmux-help() {
  cat <<'HELP'
╔════════════════════════════════════════════════════════════╗
║              TMUX QUICK REFERENCE                          ║
╠════════════════════════════════════════════════════════════╣
║ ESSENTIAL COMMANDS (Prefix = Ctrl-b)                       ║
╠════════════════════════════════════════════════════════════╣
║ Ctrl-b h         Toggle shortcuts in status bar (BEST!)    ║
║ Ctrl-b o         Switch between panes                      ║
║ Ctrl-b ;         Switch to last active pane                ║
║ Ctrl-b d         Detach from session (keeps running)       ║
║ Ctrl-b x         Kill current pane (prompts for confirm)   ║
║ Ctrl-b [         Enter scroll mode (q to exit)             ║
╠════════════════════════════════════════════════════════════╣
║ MOUSE SUPPORT (enabled by default)                         ║
╠════════════════════════════════════════════════════════════╣
║ Click            Switch to pane                            ║
║ Scroll           Scroll through history                    ║
║ Drag border      Resize panes                              ║
╠════════════════════════════════════════════════════════════╣
║ SESSION MANAGEMENT (outside tmux)                          ║
╠════════════════════════════════════════════════════════════╣
║ tmux ls          List all sessions                         ║
║ tmux attach      Attach to last session                    ║
║ tmux attach -t NAME   Attach to specific session           ║
║ tmux kill-session -t NAME   Kill a session                 ║
╠════════════════════════════════════════════════════════════╣
║ TESTING                                                     ║
╠════════════════════════════════════════════════════════════╣
║ tmux-test        Test with current directory               ║
║ tmux-test /path  Test with specific directory              ║
╚════════════════════════════════════════════════════════════╝

WORKFLOW:
  1. Run 'tmux-test' to create a session
  2. Left pane shows clod, right pane is your terminal
  3. Use Ctrl-b o to switch panes (or just click with mouse)
  4. Use Ctrl-b d to detach (session keeps running)
  5. Use 'tmux-test' again to reattach

NOTE: With mouse mode enabled, you can click panes and scroll
      without using any keyboard shortcuts!
HELP
}

# Functions loaded silently - run 'tmux-help' for usage
