#!/usr/bin/env zsh

# Bourgie Theme Plugin
# Custom functions and utilities to support the oh-my-posh bourgie theme
RAD_BOURGIE_DIR="${0:a:h}"


# Debug logging function
function _bourgie_debug() {
    if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
        local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [BOURGIE DEBUG] $*" >> "$debug_file"
    fi
}

# Initialize debug session
if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
    local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
    echo "" >> "$debug_file"
    echo "===== BOURGIE DEBUG SESSION STARTED $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$debug_file"
    echo "PID: $$" >> "$debug_file"
    echo "Shell: $SHELL" >> "$debug_file"
    echo "PWD: $PWD" >> "$debug_file"
    echo "Debug file: $debug_file" >> "$debug_file"
    echo "" >> "$debug_file"
fi

# Set up environment variables for theme configuration
[[ $GITTACULOUS_ENABLE_SSH_THEME == 'true' || -n $SSH_CLIENT ]] && GITTACULOUS_ENABLE_SSH_THEME=true || GITTACULOUS_ENABLE_SSH_THEME=false

_bourgie_debug "Setting up environment variables"
_bourgie_debug "SSH_CLIENT: ${SSH_CLIENT:-unset}"
_bourgie_debug "GITTACULOUS_ENABLE_SSH_THEME: $GITTACULOUS_ENABLE_SSH_THEME"

# Export environment variables that oh-my-posh can access
export GITTACULOUS_ENABLE_SSH_THEME
export ENABLE_DOCKER_PROMPT=${ENABLE_DOCKER_PROMPT:-false}
export ENABLE_NODE_PROMPT=${ENABLE_NODE_PROMPT:-false}
export LAZY_NODE_PROMPT=${LAZY_NODE_PROMPT:-false}
export BOURGIE_SHOW_TIME=${BOURGIE_SHOW_TIME:-false}

_bourgie_debug "Environment variables exported:"
_bourgie_debug "  GITTACULOUS_ENABLE_SSH_THEME: $GITTACULOUS_ENABLE_SSH_THEME"
_bourgie_debug "  ENABLE_DOCKER_PROMPT: $ENABLE_DOCKER_PROMPT"
_bourgie_debug "  ENABLE_NODE_PROMPT: $ENABLE_NODE_PROMPT"
_bourgie_debug "  LAZY_NODE_PROMPT: $LAZY_NODE_PROMPT"
_bourgie_debug "  BOURGIE_SHOW_TIME: $BOURGIE_SHOW_TIME"

# Export additional environment variables for oh-my-posh templates
export USER=${USER:-$(whoami)}
export HOSTNAME=${HOSTNAME:-$(hostname -s)}

_bourgie_debug "Additional environment variables:"
_bourgie_debug "  USER: $USER"
_bourgie_debug "  HOSTNAME: $HOSTNAME"

# Export NVM status for lazy loading detection
if zstyle -t ':nvm-lazy-load' nvm-loaded 'yes'; then
    export NVM_LOADED=true
    _bourgie_debug "NVM lazy loading: loaded (NVM_LOADED=true)"
else
    export NVM_LOADED=false
    _bourgie_debug "NVM lazy loading: not loaded (NVM_LOADED=false)"
fi

# Helper function to get Docker environment info
function _get-docker-prompt() {
    local docker_prompt
    docker_prompt=$DOCKER_HOST
    [[ "${docker_prompt}x" == "x" ]] && docker_prompt="unset"
    _bourgie_debug "_get-docker-prompt called: DOCKER_HOST=${DOCKER_HOST:-unset}, result='🐳 ${docker_prompt}'"
    echo -n "🐳 ${docker_prompt}"
}

# Helper function to get Node.js version info
function _get-node-prompt() {
    local node_prompt npm_prompt
    node_prompt=$(node -v 2>/dev/null)
    npm_prompt="v$(\npm -v 2>/dev/null)"
    [[ "${node_prompt}x" == "x" ]] && node_prompt="none"
    [[ "${npm_prompt}x" == "vx" ]] && npm_prompt="none"
    echo -n "⬢ ${node_prompt} npm ${npm_prompt}"
}

# Helper function to get Python virtual environment info
function _get-venv-prompt() {
    local venv_prompt=""
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # Check if it's a pipenv environment
        if [[ -n "$PIPENV_ACTIVE" ]]; then
            venv_prompt="pipenv: $(basename "$VIRTUAL_ENV")"
        else
            # Truncate the path to a reasonable limit, e.g., 20 characters
            venv_prompt="🐱 Venv: ...${VIRTUAL_ENV: -20}"
        fi
    fi
    [[ -n "$venv_prompt" ]] && echo -n "(${venv_prompt})"
}

# Helper function for current directory with SSH awareness
function _get-current-dir-prompt() {
    local infoline
    local dir_color

    # If we're in an SSH client, prepend the user and machine
    if [[ $GITTACULOUS_ENABLE_SSH_THEME == 'true' ]]; then
        # Current dir; show in yellow if not writable
        [[ -w $PWD ]] && dir_color="green" || dir_color="yellow"
        infoline="(%n@%m) (${PWD/#$HOME/~})"
    else
        # Current dir without SSH info
        infoline="(${PWD/#$HOME/~})"
    fi

    echo -n "${infoline}"
}

# Function to initialize the bourgie theme with oh-my-posh
function bourgie_init() {
    _bourgie_debug "bourgie_init called"

    # Get the directory where this plugin is located
    local plugin_dir="${RAD_BOURGIE_DIR}"
    local config_file="${plugin_dir}/posh-config.yaml"

    _bourgie_debug "Plugin directory: $plugin_dir"
    _bourgie_debug "Config file: $config_file"

    # Check if oh-my-posh is available
    if ! command -v oh-my-posh >/dev/null 2>&1; then
        _bourgie_debug "ERROR: oh-my-posh command not found"
        echo "Warning: oh-my-posh not found. Please install oh-my-posh to use the bourgie theme."
        return 1
    fi

    _bourgie_debug "oh-my-posh found at: $(command -v oh-my-posh)"

    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        _bourgie_debug "ERROR: Config file not found: $config_file"
        echo "Warning: posh-config.yaml not found at $config_file"
        return 1
    fi

    _bourgie_debug "Config file exists, initializing oh-my-posh"

    # Store config path for hot reloading
    export BOURGIE_CONFIG_FILE="$config_file"
    export BOURGIE_PLUGIN_DIR="$plugin_dir"

    # Check if hot reload mode is enabled
    if [[ "$BOURGIE_HOT_RELOAD" == "true" ]]; then
        _bourgie_debug "Hot reload mode enabled - setting up dynamic prompt"
        bourgie_init_hot_reload
    else
        # Standard initialization
        local init_cmd="oh-my-posh init zsh --config \"$config_file\""
        _bourgie_debug "Running: $init_cmd"

        eval "$(oh-my-posh init zsh --config "$config_file")"

        _bourgie_debug "oh-my-posh initialization completed"
    fi
}

# Hot reload initialization - sets up dynamic prompt that reloads config each time
function bourgie_init_hot_reload() {
    _bourgie_debug "Setting up hot reload prompt system"

    # Store original prompt setup for fallback
    export BOURGIE_FALLBACK_PS1="$PS1"

    # Set up dynamic prompt function
    function _bourgie_hot_reload_prompt() {
        local config_file="$BOURGIE_CONFIG_FILE"
        local start_time

        # Performance timing for debug
        if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
            start_time=$(date +%s.%N)
        fi

        # Check if config file still exists
        if [[ ! -f "$config_file" ]]; then
            _bourgie_debug "Config file missing during hot reload: $config_file"
            echo "bourgie-error> "
            return 1
        fi

        # Generate prompt using oh-my-posh in subshell with fresh config
        local prompt_output
        prompt_output=$(
            # Export current environment to subshell
            export GITTACULOUS_ENABLE_SSH_THEME
            export ENABLE_DOCKER_PROMPT
            export ENABLE_NODE_PROMPT
            export LAZY_NODE_PROMPT
            export BOURGIE_SHOW_TIME
            export RAD_BOURGIE_DEBUG
            export USER
            export HOSTNAME
            export NVM_LOADED

            # Run oh-my-posh with current config
            oh-my-posh print primary --config "$config_file" 2>/dev/null
        )

        # Performance timing
        if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
            local end_time=$(date +%s.%N)
            local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "unknown")
            _bourgie_debug "Hot reload prompt generation took: ${duration}s"
        fi

        # Use generated prompt or fallback
        if [[ -n "$prompt_output" ]]; then
            echo "$prompt_output"
        else
            _bourgie_debug "Hot reload failed, using fallback"
            echo "bourgie-reload> "
        fi
    }

    # Set up right prompt function for hot reload
    function _bourgie_hot_reload_rprompt() {
        local config_file="$BOURGIE_CONFIG_FILE"

        # Only generate right prompt if config file exists
        if [[ -f "$config_file" ]]; then
            local rprompt_output
            rprompt_output=$(
                # Export environment
                export GITTACULOUS_ENABLE_SSH_THEME
                export ENABLE_DOCKER_PROMPT
                export ENABLE_NODE_PROMPT
                export LAZY_NODE_PROMPT
                export BOURGIE_SHOW_TIME
                export USER
                export HOSTNAME
                export NVM_LOADED

                # Generate right prompt
                oh-my-posh print right --config "$config_file" 2>/dev/null
            )

            [[ -n "$rprompt_output" ]] && echo "$rprompt_output"
        fi
    }

    # Set the prompt to use our hot reload function
    setopt PROMPT_SUBST
    PS1='$(_bourgie_hot_reload_prompt)'
    RPS1='$(_bourgie_hot_reload_rprompt)'

    _bourgie_debug "Hot reload prompt system configured"
}

# Function to enable/disable hot reload mode
function bourgie_hot_reload() {
    local action="${1:-toggle}"

    case "$action" in
        "on"|"enable"|"true")
            export BOURGIE_HOT_RELOAD=true
            echo "🔥 Hot reload enabled - config will be reloaded with each prompt"
            echo "💡 Edit $BOURGIE_CONFIG_FILE and see changes immediately!"
            echo "⚠️  Note: This may slow down prompt rendering slightly"

            # Reinitialize with hot reload
            bourgie_init
            ;;
        "off"|"disable"|"false")
            export BOURGIE_HOT_RELOAD=false
            echo "❄️  Hot reload disabled - using cached config"

            # Reinitialize without hot reload
            bourgie_init
            ;;
        "toggle")
            if [[ "$BOURGIE_HOT_RELOAD" == "true" ]]; then
                bourgie_hot_reload off
            else
                bourgie_hot_reload on
            fi
            ;;
        "status")
            echo "🔥 Hot reload status: ${BOURGIE_HOT_RELOAD:-false}"
            if [[ "$BOURGIE_HOT_RELOAD" == "true" ]]; then
                echo "📄 Config file: $BOURGIE_CONFIG_FILE"
                echo "⏱️  Performance impact: ~50-100ms per prompt"
            fi
            ;;
        *)
            echo "Usage: bourgie_hot_reload [on|off|toggle|status]"
            echo ""
            echo "Hot reload allows you to edit the oh-my-posh config and see"
            echo "changes immediately without opening a new terminal."
            echo ""
            echo "Commands:"
            echo "  on/enable   - Enable hot reload mode"
            echo "  off/disable - Disable hot reload mode"
            echo "  toggle      - Toggle hot reload on/off"
            echo "  status      - Show current hot reload status"
            ;;
    esac
}

# Performance monitoring for hot reload
function bourgie_hot_reload_benchmark() {
    if [[ "$BOURGIE_HOT_RELOAD" != "true" ]]; then
        echo "❌ Hot reload is not enabled"
        echo "Run 'bourgie_hot_reload on' first"
        return 1
    fi

    echo "🔥 Benchmarking hot reload performance..."
    echo "Running 10 prompt generations..."

    local total_time=0
    local iterations=10

    for (( i=1; i<=iterations; i++ )); do
        local start_time=$(date +%s.%N)
        _bourgie_hot_reload_prompt >/dev/null
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")

        echo "  Iteration $i: ${duration}s"
        total_time=$(echo "$total_time + $duration" | bc 2>/dev/null || echo "$total_time")
    done

    local avg_time=$(echo "scale=3; $total_time / $iterations" | bc 2>/dev/null || echo "unknown")
    echo ""
    echo "📊 Results:"
    echo "  Total time: ${total_time}s"
    echo "  Average time per prompt: ${avg_time}s"
    echo "  Iterations: $iterations"
}

# Helper functions for the interactive wizard
function _bourgie_show_header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              🎨 Bourgie Theme Configuration                      ║"
    echo "║                        Interactive Setup & Configuration Wizard                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

function _bourgie_show_current_status() {
    echo "🔧 Current Configuration:"
    echo "  [1] SSH Theme:       ${GITTACULOUS_ENABLE_SSH_THEME:-false}"
    echo "  [2] Docker Prompt:   ${ENABLE_DOCKER_PROMPT:-false}"
    echo "  [3] Node.js Prompt:  ${ENABLE_NODE_PROMPT:-false} (Lazy: ${LAZY_NODE_PROMPT:-false})"
    echo "  [4] Time Display:    ${BOURGIE_SHOW_TIME:-false}"
    echo "  [5] Hot Reload:      ${BOURGIE_HOT_RELOAD:-false}"
    echo "  [6] Debug Logging:   ${RAD_BOURGIE_DEBUG:-false}"
    echo ""
}

function _bourgie_prompt_user() {
    echo -n "$1: "
    read -r response
    echo "$response"
}

function _bourgie_wizard_docker() {
    echo ""
    echo "🐳 Docker Environment Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Current setting: ${ENABLE_DOCKER_PROMPT:-false}"
    echo ""
    echo "Docker prompt shows container information when available."
    echo ""
    local choice
    choice=$(_bourgie_prompt_user "Enable Docker prompt? [y/N]")
    case "${choice,,}" in
        y|yes|true|1)
            export ENABLE_DOCKER_PROMPT=true
            echo "✅ Docker prompt enabled"
            ;;
        *)
            export ENABLE_DOCKER_PROMPT=false
            echo "❌ Docker prompt disabled"
            ;;
    esac
}

function _bourgie_wizard_node() {
    echo ""
    echo "⬢ Node.js Environment Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Current setting: ENABLE_NODE_PROMPT=${ENABLE_NODE_PROMPT:-false}, LAZY_NODE_PROMPT=${LAZY_NODE_PROMPT:-false}"
    echo ""
    echo "Node.js prompt options:"
    echo "  [1] Always show Node.js version"
    echo "  [2] Lazy loading (show only when nvm is loaded)"
    echo "  [3] Disable Node.js prompt"
    echo ""
    local choice
    choice=$(_bourgie_prompt_user "Choose option [1-3]")
    case "$choice" in
        1)
            export ENABLE_NODE_PROMPT=true
            export LAZY_NODE_PROMPT=false
            echo "✅ Node.js prompt always enabled"
            ;;
        2)
            export ENABLE_NODE_PROMPT=false
            export LAZY_NODE_PROMPT=true
            echo "✅ Lazy Node.js prompt enabled"
            ;;
        *)
            export ENABLE_NODE_PROMPT=false
            export LAZY_NODE_PROMPT=false
            echo "❌ Node.js prompt disabled"
            ;;
    esac
}

function _bourgie_wizard_ssh() {
    echo ""
    echo "🔐 SSH Theme Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Current setting: ${GITTACULOUS_ENABLE_SSH_THEME:-false}"
    echo ""
    echo "SSH theme shows user@hostname when connected via SSH."
    echo ""
    local choice
    choice=$(_bourgie_prompt_user "Enable SSH theme? [y/N]")
    case "${choice,,}" in
        y|yes|true|1)
            export GITTACULOUS_ENABLE_SSH_THEME=true
            echo "✅ SSH theme enabled"
            ;;
        *)
            export GITTACULOUS_ENABLE_SSH_THEME=false
            echo "❌ SSH theme disabled"
            ;;
    esac
}

function _bourgie_wizard_time() {
    echo ""
    echo "⏰ Time Display Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Current setting: ${BOURGIE_SHOW_TIME:-false}"
    echo ""
    echo "Time display shows current time in the right prompt."
    echo ""
    local choice
    choice=$(_bourgie_prompt_user "Enable time display? [y/N]")
    case "${choice,,}" in
        y|yes|true|1)
            export BOURGIE_SHOW_TIME=true
            echo "✅ Time display enabled"
            ;;
        *)
            export BOURGIE_SHOW_TIME=false
            echo "❌ Time display disabled"
            ;;
    esac
}

function _bourgie_wizard_hot_reload() {
    echo ""
    echo "🔥 Hot Reload Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Current setting: ${BOURGIE_HOT_RELOAD:-false}"
    if [[ "$BOURGIE_HOT_RELOAD" == "true" ]]; then
        echo "Config file: ${BOURGIE_CONFIG_FILE:-unknown}"
    fi
    echo ""
    echo "Hot reload allows you to edit the oh-my-posh config and see changes"
    echo "immediately without opening a new terminal. Perfect for theme development!"
    echo ""
    echo "⚠️  Note: Hot reload adds ~50-100ms to prompt rendering time."
    echo ""
    local choice
    choice=$(_bourgie_prompt_user "Enable hot reload? [y/N]")
    case "${choice,,}" in
        y|yes|true|1)
            bourgie_hot_reload on
            echo "✅ Hot reload enabled"
            echo "💡 Edit your config file and see changes immediately!"
            ;;
        *)
            bourgie_hot_reload off
            echo "❌ Hot reload disabled"
            ;;
    esac
}

function _bourgie_wizard_debug() {
    echo ""
    echo "🐛 Debug Logging Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Current setting: ${RAD_BOURGIE_DEBUG:-false}"
    echo "Debug file: ${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
    echo ""
    echo "Debug logging helps troubleshoot theme issues."
    echo ""
    local choice
    choice=$(_bourgie_prompt_user "Enable debug logging? [y/N]")
    case "${choice,,}" in
        y|yes|true|1)
            export RAD_BOURGIE_DEBUG=true
            local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
            echo "✅ Debug logging enabled"
            echo "📁 Log file: $debug_file"
            echo "💡 Use 'bourgie_config debug tail' to follow the log"
            ;;
        *)
            export RAD_BOURGIE_DEBUG=false
            echo "❌ Debug logging disabled"
            ;;
    esac
}

# Interactive wizard function
function _bourgie_run_wizard() {
    _bourgie_show_header
    _bourgie_show_current_status

    echo "🚀 Configuration Options:"
    echo "  [1] Configure SSH Theme"
    echo "  [2] Configure Docker Prompt"
    echo "  [3] Configure Node.js Prompt"
    echo "  [4] Configure Time Display"
    echo "  [5] Configure Hot Reload"
    echo "  [6] Configure Debug Logging"
    echo "  [7] Run Full Setup Wizard"
    echo "  [8] Show Current Status"
    echo "  [q] Quit"
    echo ""

    local choice
    choice=$(_bourgie_prompt_user "Choose an option [1-8,q]")

    case "$choice" in
        1) _bourgie_wizard_ssh ;;
        2) _bourgie_wizard_docker ;;
        3) _bourgie_wizard_node ;;
        4) _bourgie_wizard_time ;;
        5) _bourgie_wizard_hot_reload ;;
        6) _bourgie_wizard_debug ;;
        7)
            echo ""
            echo "🧙‍♂️ Running Full Setup Wizard..."
            _bourgie_wizard_ssh
            _bourgie_wizard_docker
            _bourgie_wizard_node
            _bourgie_wizard_time
            _bourgie_wizard_hot_reload
            _bourgie_wizard_debug
            echo ""
            echo "🎉 Full setup completed!"
            ;;
        8)
            _bourgie_show_current_status
            ;;
        q|quit|exit)
            echo "👋 Exiting wizard. Configuration saved!"
            return 0
            ;;
        *)
            echo "❌ Invalid option. Please choose 1-8 or q."
            ;;
    esac

    echo ""
    local continue_choice
    continue_choice=$(_bourgie_prompt_user "Continue configuring? [Y/n]")
    case "${continue_choice,,}" in
        n|no|quit|exit)
            echo "👋 Configuration complete!"
            return 0
            ;;
        *)
            _bourgie_run_wizard
            ;;
    esac
}

# Function to update environment variables that control prompt segments
function bourgie_config() {
    _bourgie_debug "bourgie_config called with args: $*"

    # If no arguments provided, launch the interactive wizard
    if [[ $# -eq 0 ]]; then
        _bourgie_run_wizard
        return 0
    fi

    # Handle traditional CLI commands for backward compatibility
    case "$1" in
        "wizard"|"interactive")
            _bourgie_run_wizard
            ;;
        "docker")
            case "$2" in
                "on"|"true"|"enable")
                    export ENABLE_DOCKER_PROMPT=true
                    _bourgie_debug "Docker prompt enabled: ENABLE_DOCKER_PROMPT=$ENABLE_DOCKER_PROMPT"
                    echo "Docker prompt enabled"
                    ;;
                "off"|"false"|"disable")
                    export ENABLE_DOCKER_PROMPT=false
                    _bourgie_debug "Docker prompt disabled: ENABLE_DOCKER_PROMPT=$ENABLE_DOCKER_PROMPT"
                    echo "Docker prompt disabled"
                    ;;
                *)
                    _bourgie_debug "Invalid docker config option: $2"
                    echo "Usage: bourgie_config docker [on|off]"
                    echo "Current setting: $ENABLE_DOCKER_PROMPT"
                    ;;
            esac
            ;;
        "node")
            case "$2" in
                "on"|"true"|"enable")
                    export ENABLE_NODE_PROMPT=true
                    echo "Node prompt enabled"
                    ;;
                "off"|"false"|"disable")
                    export ENABLE_NODE_PROMPT=false
                    echo "Node prompt disabled"
                    ;;
                "lazy")
                    export LAZY_NODE_PROMPT=true
                    export ENABLE_NODE_PROMPT=false
                    echo "Lazy Node prompt enabled (shows only when nvm is loaded)"
                    ;;
                *)
                    echo "Usage: bourgie_config node [on|off|lazy]"
                    echo "Current setting: ENABLE_NODE_PROMPT=$ENABLE_NODE_PROMPT, LAZY_NODE_PROMPT=$LAZY_NODE_PROMPT"
                    ;;
            esac
            ;;
        "ssh")
            case "$2" in
                "on"|"true"|"enable")
                    export GITTACULOUS_ENABLE_SSH_THEME=true
                    echo "SSH theme enabled"
                    ;;
                "off"|"false"|"disable")
                    export GITTACULOUS_ENABLE_SSH_THEME=false
                    echo "SSH theme disabled"
                    ;;
                *)
                    echo "Usage: bourgie_config ssh [on|off]"
                    echo "Current setting: $GITTACULOUS_ENABLE_SSH_THEME"
                    ;;
            esac
            ;;
        "time")
            case "$2" in
                "on"|"true"|"enable")
                    export BOURGIE_SHOW_TIME=true
                    echo "Right prompt time display enabled"
                    ;;
                "off"|"false"|"disable")
                    export BOURGIE_SHOW_TIME=false
                    echo "Right prompt time display disabled"
                    ;;
                *)
                    echo "Usage: bourgie_config time [on|off]"
                    echo "Current setting: $BOURGIE_SHOW_TIME"
                    ;;
            esac
            ;;
        "hot-reload"|"reload")
            case "$2" in
                "on"|"true"|"enable")
                    bourgie_hot_reload on
                    ;;
                "off"|"false"|"disable")
                    bourgie_hot_reload off
                    ;;
                "toggle")
                    bourgie_hot_reload toggle
                    ;;
                "status")
                    bourgie_hot_reload status
                    ;;
                "benchmark")
                    bourgie_hot_reload_benchmark
                    ;;
                *)
                    echo "Usage: bourgie_config hot-reload [on|off|toggle|status|benchmark]"
                    echo "Current setting: ${BOURGIE_HOT_RELOAD:-false}"
                    ;;
            esac
            ;;
        "status"|"show")
            echo "Bourgie Theme Configuration:"
            echo "  SSH Theme: $GITTACULOUS_ENABLE_SSH_THEME"
            echo "  Docker Prompt: $ENABLE_DOCKER_PROMPT"
            echo "  Node Prompt: $ENABLE_NODE_PROMPT"
            echo "  Lazy Node Prompt: $LAZY_NODE_PROMPT"
            echo "  Show Time: $BOURGIE_SHOW_TIME"
            echo "  Hot Reload: ${BOURGIE_HOT_RELOAD:-false}"
            echo "  Debug Logging: ${RAD_BOURGIE_DEBUG:-false}"
            if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
                local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
                echo "  Debug File: $debug_file"
                if [[ -f "$debug_file" ]]; then
                    local log_size=$(wc -l < "$debug_file" 2>/dev/null || echo "0")
                    echo "  Log Lines: $log_size"
                fi
            fi
            if [[ "$BOURGIE_HOT_RELOAD" == "true" ]]; then
                echo "  Config File: ${BOURGIE_CONFIG_FILE:-unknown}"
            fi
            ;;
        "debug")
            case "$2" in
                "on"|"true"|"enable")
                    export RAD_BOURGIE_DEBUG=true
                    local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
                    echo "Debug logging enabled. Log file: $debug_file"
                    echo "Use 'bourgie_config debug tail' to follow the log in real-time"
                    ;;
                "off"|"false"|"disable")
                    export RAD_BOURGIE_DEBUG=false
                    echo "Debug logging disabled"
                    ;;
                "tail")
                    local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
                    if [[ -f "$debug_file" ]]; then
                        echo "Following debug log: $debug_file (Ctrl+C to exit)"
                        tail -f "$debug_file"
                    else
                        echo "Debug file not found: $debug_file"
                        echo "Enable debugging first with: bourgie_config debug on"
                    fi
                    ;;
                "show"|"cat")
                    local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
                    if [[ -f "$debug_file" ]]; then
                        echo "=== Debug log contents: $debug_file ==="
                        cat "$debug_file"
                    else
                        echo "Debug file not found: $debug_file"
                        echo "Enable debugging first with: bourgie_config debug on"
                    fi
                    ;;
                "clear")
                    local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
                    > "$debug_file"
                    echo "Debug log cleared: $debug_file"
                    ;;
                *)
                    echo "Usage: bourgie_config debug [on|off|tail|show|clear]"
                    echo "Current setting: RAD_BOURGIE_DEBUG=${RAD_BOURGIE_DEBUG:-false}"
                    echo "Log file: ${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
                    ;;
            esac
            ;;
        *)
            echo "🎨 Bourgie Theme Configuration"
            echo ""
            echo "Usage: bourgie_config [command] [options]"
            echo ""
            echo "📋 Interactive Commands:"
            echo "  bourgie_config                    - Launch interactive wizard"
            echo "  bourgie_config wizard             - Launch interactive wizard"
            echo ""
            echo "⚙️  Traditional CLI Commands:"
            echo "  bourgie_config docker [on|off]                - Toggle Docker environment display"
            echo "  bourgie_config node [on|off|lazy]             - Toggle Node.js version display"
            echo "  bourgie_config ssh [on|off]                   - Toggle SSH-specific theme"
            echo "  bourgie_config time [on|off]                  - Toggle right prompt time display"
            echo "  bourgie_config hot-reload [on|off|toggle]     - Toggle config hot reloading"
            echo "  bourgie_config debug [on|off|tail|show]       - Control debug logging"
            echo "  bourgie_config status                         - Show current configuration"
            echo ""
            echo "💡 Tip: Run 'bourgie_config' without arguments for the interactive wizard!"
            ;;
    esac
}

# Auto-initialize the theme when the plugin is loaded
# Users can override this by setting BOURGIE_NO_AUTO_INIT=true
_bourgie_debug "Auto-initialization check: BOURGIE_NO_AUTO_INIT=${BOURGIE_NO_AUTO_INIT:-unset}"

if [[ "$BOURGIE_NO_AUTO_INIT" != "true" ]]; then
    _bourgie_debug "Auto-initializing bourgie theme"
    if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
        # Show debug output when debug is enabled
        bourgie_init
    else
        # Hide output when debug is disabled
        bourgie_init >/dev/null 2>&1
    fi
else
    _bourgie_debug "Auto-initialization skipped (BOURGIE_NO_AUTO_INIT=true)"
fi

