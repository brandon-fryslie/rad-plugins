# Ensure this runs in a subshell - note the parens rather than curly braces
clod () (
    export SHELL=bash
    claude --dangerously-skip-permissions "$@"
)

cclod() {
  local session_name="${PWD:t}"
  local port=""
  local cc_dump_running=0

  # Function to find free port
  find_free_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'
  }

  # Determine target window
  local target
  local need_attach=0

  if [[ -n $TMUX ]]; then
    # Already in tmux, use current window
    target=$(tmux display-message -p '#S:#I')
  else
    # Not in tmux, create/use session named after current directory
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
      tmux new-session -s "$session_name" -d -c "$PWD"
    fi
    target="$session_name:0"
    need_attach=1
  fi

  # Get all pane PIDs in target window
  local pane_pids=$(tmux list-panes -t "$target" -F '#{pane_pid}' 2>/dev/null)

  # Check each pane for cc-dump and extract port if found
  for pane_pid in ${(f)pane_pids}; do
    # Check if this pane or its children are running cc-dump
    if pgrep -P $pane_pid -f 'cc-dump.*--port' >/dev/null 2>&1; then
      cc_dump_running=1
      local cc_dump_pid=$(pgrep -P $pane_pid -f 'cc-dump.*--port')
      port=$(ps -p $cc_dump_pid -o args= | grep -o -- '--port [0-9]\+' | awk '{print $2}')
      break
    fi
  done

  # If no port found from existing cc-dump, find a free one
  [[ -z $port ]] && port=$(find_free_port)

  # Get pane count
  local pane_count=$(echo "$pane_pids" | wc -l | tr -d ' ')

  # If only one pane, split vertically and potentially start cc-dump
  if [[ $pane_count -eq 1 ]]; then
    tmux split-window -h -t "$target" -c "$PWD"
    # Only start cc-dump if it's not already running
    if [[ $cc_dump_running -eq 0 ]]; then
      tmux send-keys -t "${target}.1" "cc-dump --port $port" C-m
    fi
  fi

  # Run clod in left pane with ANTHROPIC_BASE_URL set to local port
  tmux send-keys -t "${target}.0" "ANTHROPIC_BASE_URL=http://127.0.0.1:$port clod \"$@\"" C-m

  # Attach to session if we weren't already in tmux
  [[ $need_attach -eq 1 ]] && tmux attach-session -t "$session_name"
}

setup_claude_config_dir() {
  local service=$1 # minimax or zai
  local claude_config_dir="$DOTFILES_DIR/config/claude"
  local service_config_dir="${claude_config_dir}.${service}"

  # TODO: symlink things?
}

get_claude_config_dir() {
  local main_config_dir="$DOTFILES_DIR/config/claude"
  [[ -z $1 ]] && { echo "${main_config_dir}"; return; }
  local service_config_dir="${main_config_dir}.${1}"
  mkdir -p "${service_config_dir}"
  echo "${service_config_dir}"
}

claude_service() {
  local service_name=$1
  [[ -z $service_name ]] && { rad-red "ERROR: Must provide service name"; return 1; }
  local claude_config_dir="$(get_claude_config_dir)"
  local claude_service_config_dir="$(get_claude_config_dir "${service_name}")"
  export CLAUDE_CONFIG_DIR="${claude_service_config_dir}"
  dotenvx run -f "${claude_config_dir}/.env.${service_name}" -- claude --dangerously-skip-permissions --settings "${claude_config_dir}/settings.${service_name}.json" "$@"
}

mlod() {
  claude_service minimax
}

zlod() {
  claude_service zai
}

coplod() {
  local copilot_port=4141
  local copilot_session="copilot-api"
  local session_name="${PWD:t}"

  # Ensure copilot-api is installed
  type -v copilot-api >&/dev/null || pnpm install -g copilot-api

  # Start copilot-api if not already running on port 4141
  if ! lsof -i ":${copilot_port}" -sTCP:LISTEN >/dev/null 2>&1; then
    # Run copilot-api in a detached tmux session
    tmux kill-session -t "$copilot_session" 2>/dev/null
    tmux new-session -d -s "$copilot_session" "copilot-api start --port $copilot_port"

    # Wait for copilot-api to be ready
    local retries=30
    while (( retries-- > 0 )); do
      curl -sf "http://localhost:${copilot_port}/v1/models" >/dev/null 2>&1 && break
      sleep 0.5
    done

    if ! curl -sf "http://localhost:${copilot_port}/v1/models" >/dev/null 2>&1; then
      echo "ERROR: copilot-api failed to start on port $copilot_port" >&2
      return 1
    fi
  fi

  # Find a free port for cc-dump
  local dump_port
  dump_port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')

  # Create/reuse tmux session, add a new window with two panes
  local target
  local need_attach=0

  if [[ -n $TMUX ]]; then
    # Already in tmux — create a new window in current session
    tmux new-window -c "$PWD"
    target=$(tmux display-message -p '#S:#I')
  else
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
      tmux new-session -s "$session_name" -d -c "$PWD"
    else
      tmux new-window -t "$session_name" -c "$PWD"
    fi
    target="${session_name}:$(tmux list-windows -t "$session_name" -F '#I' | tail -1)"
    need_attach=1
  fi

  # Split vertically: left pane for claude, right pane for cc-dump
  tmux split-window -h -t "$target" -c "$PWD"

  # Right pane: start cc-dump proxying through copilot-api
  tmux send-keys -t "${target}.1" "cc-dump --port $dump_port --target http://localhost:${copilot_port}" C-m

  # Left pane: start clod with copilot-api env vars (inline, not exported)
  tmux send-keys -t "${target}.0" "ANTHROPIC_AUTH_TOKEN=sk-dummy ANTHROPIC_MODEL=claude-opus-4.6 ANTHROPIC_DEFAULT_HAIKU_MODEL=gpt-5-mini DISABLE_NON_ESSENTIAL_MODEL_CALLS=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 ANTHROPIC_BASE_URL=http://127.0.0.1:$dump_port clod $*" C-m

  # Attach if we weren't already in tmux
  [[ $need_attach -eq 1 ]] && tmux attach-session -t "$session_name"
}