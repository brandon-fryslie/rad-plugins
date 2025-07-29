#!/usr/bin/env zsh

# Bourgie DSL - A lightweight Domain Specific Language for oh-my-posh segment definitions
# This provides an intuitive way to define prompt segments with natural syntax

# Global DSL state
typeset -g BOURGIE_DSL_SEGMENTS=()
typeset -g BOURGIE_DSL_BLOCKS=()
typeset -g BOURGIE_DSL_CURRENT_BLOCK=""
typeset -g BOURGIE_DSL_PALETTE=()
typeset -g BOURGIE_DSL_CONFIG=()

# Color palette definitions (Nord theme by default)
typeset -gA BOURGIE_COLORS=(
    # Nord Polar Night
    [black]="#2E3440"
    [dark_gray]="#3B4252" 
    [gray]="#434C5E"
    [light_gray]="#4C566A"
    
    # Nord Snow Storm
    [dark_white]="#D8DEE9"
    [white]="#E5E9F0"
    [bright_white]="#ECEFF4"
    
    # Nord Frost
    [teal]="#8FBCBB"
    [cyan]="#88C0D0"
    [blue]="#81A1C1"
    [dark_blue]="#5E81AC"
    
    # Nord Aurora
    [red]="#BF616A"
    [orange]="#D08770"
    [yellow]="#EBCB8B"
    [green]="#A3BE8C"
    [purple]="#B48EAD"
    
    # Semantic colors
    [success]="#A3BE8C"
    [warning]="#EBCB8B"
    [error]="#BF616A"
    [info]="#81A1C1"
    [subtle]="#4C566A"
    [primary]="#88C0D0"
    
    # Transparent
    [transparent]="transparent"
)

# DSL Helper Functions
function _dsl_debug() {
    if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
        _bourgie_debug "[DSL] $*"
    fi
}

# Initialize DSL
function dsl_init() {
    _dsl_debug "Initializing Bourgie DSL"
    BOURGIE_DSL_SEGMENTS=()
    BOURGIE_DSL_BLOCKS=()
    BOURGIE_DSL_CURRENT_BLOCK=""
    BOURGIE_DSL_PALETTE=()
    BOURGIE_DSL_CONFIG=()
}

# Color helper - resolves color names to hex values
function dsl_color() {
    local color_name="$1"
    if [[ -n "${BOURGIE_COLORS[$color_name]}" ]]; then
        echo "${BOURGIE_COLORS[$color_name]}"
    else
        # Assume it's already a hex color or valid CSS color
        echo "$color_name"
    fi
}

# Add custom color to palette
function dsl_add_color() {
    local name="$1"
    local value="$2"
    BOURGIE_COLORS[$name]="$value"
    _dsl_debug "Added custom color: $name = $value"
}

# Template helper functions
function dsl_env() {
    echo ".Env.$1"
}

function dsl_if() {
    local condition="$1"
    echo "{{ if $condition }}"
}

function dsl_endif() {
    echo "{{ end }}"
}

function dsl_not() {
    echo "not $1"
}

function dsl_and() {
    echo "and $1 $2"
}

function dsl_or() {
    echo "or $1 $2"
}

# Segment definition functions

# Create a new prompt block
function dsl_block() {
    local type="${1:-prompt}"
    local alignment="${2:-left}"
    
    BOURGIE_DSL_CURRENT_BLOCK="block_$(( ${#BOURGIE_DSL_BLOCKS[@]} + 1 ))"
    
    local block="
  - type: $type
    alignment: $alignment
    segments:"
    
    BOURGIE_DSL_BLOCKS+=("$block")
    _dsl_debug "Created block: $type ($alignment)"
}

# Add newline to current block
function dsl_newline() {
    if [[ -n "$BOURGIE_DSL_CURRENT_BLOCK" ]]; then
        BOURGIE_DSL_BLOCKS[-1]="${BOURGIE_DSL_BLOCKS[-1]}
    newline: true"
        _dsl_debug "Added newline to current block"
    fi
}

# Create a right prompt block
function dsl_rprompt() {
    dsl_block "rprompt" "right"
}

# Generic segment creation
function dsl_segment() {
    local type="$1"; shift
    local -A opts
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --template|-t) opts[template]="$2"; shift 2 ;;
            --foreground|-fg) opts[foreground]="$(dsl_color "$2")"; shift 2 ;;
            --background|-bg) opts[background]="$(dsl_color "$2")"; shift 2 ;;
            --style|-s) opts[style]="$2"; shift 2 ;;
            --condition|-if) opts[condition]="$2"; shift 2 ;;
            --cache) opts[cache_duration]="$2"; shift 2 ;;
            --*) 
                local key="${1#--}"
                opts[$key]="$2"
                shift 2
                ;;
            *) break ;;
        esac
    done
    
    # Set defaults
    [[ -z "${opts[style]}" ]] && opts[style]="plain"
    [[ -z "${opts[background]}" ]] && opts[background]="transparent"
    [[ -z "${opts[cache_duration]}" ]] && opts[cache_duration]="none"
    
    # Build segment YAML
    local segment="
      - type: $type
        style: ${opts[style]}
        background: ${opts[background]}"
    
    [[ -n "${opts[foreground]}" ]] && segment="$segment
        foreground: ${opts[foreground]}"
    
    [[ -n "${opts[template]}" ]] && segment="$segment
        template: '${opts[template]}'"
        
    # Add properties section if needed
    local properties=""
    [[ -n "${opts[cache_duration]}" ]] && properties="$properties
          cache_duration: ${opts[cache_duration]}"
    
    # Add type-specific properties
    for key value in ${(kv)opts}; do
        case "$key" in
            template|foreground|background|style|condition|cache_duration) ;;
            *) properties="$properties
          $key: $value" ;;
        esac
    done
    
    if [[ -n "$properties" ]]; then
        segment="$segment
        properties:$properties"
    fi
    
    # Wrap in condition if specified
    if [[ -n "${opts[condition]}" ]]; then
        local conditional_template
        if [[ -n "${opts[template]}" ]]; then
            conditional_template="$(dsl_if "${opts[condition]}")${opts[template]}$(dsl_endif)"
        else
            conditional_template="$(dsl_if "${opts[condition]}"){{ . }}$(dsl_endif)"
        fi
        segment="${segment%template: *}
        template: '$conditional_template'"
    fi
    
    BOURGIE_DSL_SEGMENTS+=("$segment")
    _dsl_debug "Created $type segment with template: ${opts[template]}"
}

# Specific segment types with intuitive APIs

# Text segment - for static or simple dynamic text
function dsl_text() {
    local text="$1"; shift
    dsl_segment "text" --template "$text" "$@"
}

# Session segment - shows user/hostname info
function dsl_session() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ if .Env.SSH_CLIENT }}({{ .Env.USER }}@{{ .Env.HOSTNAME }}) {{ end }}'
    shift
    dsl_segment "session" --template "$template" "$@"
}

# Path segment - shows current directory
function dsl_path() {
    local template="$1"
    [[ -z "$template" ]] && template='({{ .Path }}) '
    shift
    dsl_segment "path" --template "$template" --style "full" --home_icon "~" "$@"
}

# Git segment - shows git repository information
function dsl_git() {
    local template="$1"
    [[ -z "$template" ]] && template='(git) {{ .HEAD }} {{ if .Working.Changed }}S{{ end }}{{ if .Staging.Changed }}U{{ end }} {{ .HEAD }}{{ if .Upstream }} [{{ .Upstream }}{{ if .Behind }}-{{ .Behind }}{{ end }}{{ if .Ahead }}+{{ .Ahead }}{{ end }}]{{ end }}{{ if gt .StashCount 0 }} ({{ .StashCount }} stashed){{ end }}{{ if .User.Name }} ({{ .User.Name }}){{ end }}'
    shift
    dsl_segment "git" --template "$template" \
        --fetch_stash_count "true" \
        --fetch_status "true" \
        --fetch_upstream_icon "true" \
        --fetch_user "true" \
        "$@"
}

# Python segment - shows Python virtual environment
function dsl_python() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ if .Error }}{{ else }}{{ if .Venv }}(🐱 Venv: {{ .Venv }}) {{ end }}{{ end }}'
    shift
    dsl_segment "python" --template "$template" "$@"
}

# Node segment - shows Node.js version
function dsl_node() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ if or .Env.ENABLE_NODE_PROMPT (and .Env.LAZY_NODE_PROMPT .Env.NVM_LOADED) }}⬢ {{ .Full }} {{ end }}'
    shift
    dsl_segment "node" --template "$template" "$@"
}

# NPM segment - shows npm version
function dsl_npm() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ if or .Env.ENABLE_NODE_PROMPT (and .Env.LAZY_NODE_PROMPT .Env.NVM_LOADED) }}npm {{ .Full }} {{ end }}'
    shift
    dsl_segment "npm" --template "$template" "$@"
}

# Docker segment - shows Docker environment
function dsl_docker() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ if .Env.ENABLE_DOCKER_PROMPT }}🐳  {{ .Env.DOCKER_HOST | default "unset" }} {{ end }}'
    shift
    dsl_segment "text" --template "$template" "$@"
}

# Time segment - shows current time
function dsl_time() {
    local template="$1"
    local format="${2:-15:04:05}"
    [[ -z "$template" ]] && template='{{ if .Env.BOURGIE_SHOW_TIME }}{{ .CurrentDate | date .Format }}{{ end }}'
    shift; shift
    dsl_segment "time" --template "$template" --time_format "$format" "$@"
}

# Exit segment - shows exit code and prompt character
function dsl_exit() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ if .Root }}# {{ else }}% {{ end }}'
    shift
    
    local fg_template='{{ if gt .Code 0 }}error{{ else }}bright_white{{ end }}'
    
    dsl_segment "exit" --template "$template" \
        --foreground_templates "- '$fg_template'" \
        "$@"
}

# Shell segment - shows background job count
function dsl_shell() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ if gt .JobCount 0 }}{{ .JobCount }} {{ end }}'
    shift
    dsl_segment "shell" --template "$template" "$@"
}

# Conditional segment helpers
function dsl_when() {
    local condition="$1"
    local template="$2"
    shift 2
    echo "$(dsl_if "$condition")$template$(dsl_endif)"
}

function dsl_unless() {
    local condition="$1"
    local template="$2"
    shift 2
    echo "$(dsl_if "$(dsl_not "$condition")")$template$(dsl_endif)"
}

# Environment condition helpers
function dsl_if_ssh() {
    dsl_when ".Env.SSH_CLIENT" "$@"
}

function dsl_if_docker() {
    dsl_when ".Env.ENABLE_DOCKER_PROMPT" "$@"
}

function dsl_if_node() {
    dsl_when "$(dsl_or "$(dsl_env ENABLE_NODE_PROMPT)" "$(dsl_and "$(dsl_env LAZY_NODE_PROMPT)" "$(dsl_env NVM_LOADED)")")" "$@"
}

function dsl_if_git() {
    dsl_when ".IsWorkTree" "$@"
}

function dsl_if_venv() {
    dsl_when ".Venv" "$@"
}

# Styling helpers
function dsl_with_icon() {
    local icon="$1"
    local text="$2"
    echo "$icon $text"
}

function dsl_wrap() {
    local left="$1"
    local content="$2"
    local right="$3"
    echo "$left$content$right"
}

function dsl_parentheses() {
    dsl_wrap "(" "$1" ")"
}

function dsl_brackets() {
    dsl_wrap "[" "$1" "]"
}

function dsl_braces() {
    dsl_wrap "{" "$1" "}"
}

# Compile DSL to YAML configuration
function dsl_compile() {
    local output_file="$1"
    [[ -z "$output_file" ]] && output_file="posh-config-dsl.yaml"
    
    _dsl_debug "Compiling DSL to YAML: $output_file"
    
    # Build complete YAML configuration
    local yaml_config="# Generated by Bourgie DSL
# yaml-language-server: \$schema=https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json

palette:"
    
    # Add color palette
    for color_name color_value in ${(kv)BOURGIE_COLORS}; do
        [[ "$color_value" != "transparent" ]] && yaml_config="$yaml_config
  primary_${color_name}: '$color_value'"
    done
    
    yaml_config="$yaml_config

console_title_template: '{{ .Shell }} in {{ .Folder }}'
blocks:"
    
    # Add all blocks and their segments
    local block_index=0
    for block in "${BOURGIE_DSL_BLOCKS[@]}"; do
        yaml_config="$yaml_config$block"
        
        # Add segments for this block
        local segment_start=$((block_index * 10))  # Rough estimation
        local segment_end=$((segment_start + 10))
        
        for (( i = 0; i < ${#BOURGIE_DSL_SEGMENTS[@]}; i++ )); do
            yaml_config="$yaml_config${BOURGIE_DSL_SEGMENTS[$i]}"
        done
        
        ((block_index++))
    done
    
    yaml_config="$yaml_config
version: 3
final_space: true"
    
    # Write to file
    echo "$yaml_config" > "$output_file"
    _dsl_debug "DSL compiled successfully to: $output_file"
    echo "✅ DSL compiled to: $output_file"
}

# Load and execute DSL file
function dsl_load() {
    local dsl_file="$1"
    
    if [[ ! -f "$dsl_file" ]]; then
        echo "❌ DSL file not found: $dsl_file"
        return 1
    fi
    
    _dsl_debug "Loading DSL file: $dsl_file"
    
    # Initialize DSL state
    dsl_init
    
    # Source the DSL file
    source "$dsl_file"
    
    _dsl_debug "DSL file loaded successfully"
}

# Example usage and validation
function dsl_example() {
    echo "Creating example DSL configuration..."
    
    dsl_init
    
    # Define custom colors
    dsl_add_color "brand" "#FF6B6B"
    dsl_add_color "accent" "#4ECDC4"
    
    # Main prompt block
    dsl_block "prompt" "left"
    
    # SSH session info
    dsl_session "" --foreground "black"
    
    # Current directory
    dsl_path "" --foreground "success" --condition ".Writable" \
               --foreground "warning" --condition "$(dsl_not ".Writable")"
    
    # Docker environment
    dsl_docker "" --foreground "cyan"
    
    # Python virtual environment
    dsl_python "" --foreground "orange"
    
    # Node.js environment
    dsl_node "" --foreground "green"
    dsl_npm "" --foreground "yellow"
    
    # Git information block
    dsl_newline
    dsl_block "prompt" "left"
    dsl_git "" --foreground "white"
    
    # Prompt character block
    dsl_newline  
    dsl_block "prompt" "left"
    dsl_shell "" --foreground "white"
    dsl_exit "" 
    
    # Right prompt for time
    dsl_rprompt
    dsl_time "" "15:04:05" --foreground "subtle"
    
    # Compile to YAML
    dsl_compile "example-dsl-config.yaml"
}

_dsl_debug "Bourgie DSL loaded"