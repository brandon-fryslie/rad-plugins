#!/usr/bin/env zsh

# Bourgie Theme DSL Configuration
# This file demonstrates the natural syntax for defining oh-my-posh segments

# Initialize the DSL
dsl_init

# Define custom brand colors
dsl_add_color "brand_primary" "#88C0D0"
dsl_add_color "brand_secondary" "#A3BE8C"
dsl_add_color "accent" "#EBCB8B"

# =============================================================================
# MAIN PROMPT LINE
# =============================================================================

dsl_block "prompt" "left"

# SSH session information (shows when connected via SSH)
dsl_session \
    "$(dsl_if_ssh "({{ .Env.USER }}@{{ .Env.HOSTNAME }}) ")" \
    --foreground "black"

# Current directory path
dsl_path \
    "({{ .Path }}) " \
    --foreground "success" \
    --foreground_templates \
        "- '{{ if .Writable }}success{{ else }}warning{{ end }}'"

# Docker environment (conditional)
dsl_text \
    "$(dsl_if_docker "$(dsl_with_icon "🐳" "{{ .Env.DOCKER_HOST | default \"unset\" }}") ")" \
    --foreground "cyan"

# Python virtual environment
dsl_python \
    "$(dsl_if_venv "$(dsl_parentheses "$(dsl_with_icon "🐱" "Venv: {{ .Venv }}")") ")" \
    --foreground "orange"

# Node.js version (with lazy loading support)
dsl_node \
    "$(dsl_if_node "$(dsl_with_icon "⬢" "{{ .Full }}") ")" \
    --foreground "green"

# NPM version (matches Node.js condition)
dsl_npm \
    "$(dsl_if_node "npm {{ .Full }} ")" \
    --foreground "yellow"

# Local user (shown when not in SSH)
dsl_session \
    "$(dsl_unless ".Env.SSH_CLIENT" "({{ .UserName }})")" \
    --foreground "black"

# =============================================================================
# GIT INFORMATION LINE
# =============================================================================

dsl_newline
dsl_block "prompt" "left"

# Comprehensive git information
dsl_git \
    "$(dsl_wrap "(" "git" ") {{ .HEAD }} {{ if .Working.Changed }}S{{ end }}{{ if .Staging.Changed }}U{{ end }} {{ .HEAD }}{{ if .Upstream }} {{ .Upstream }}{{ if .Behind }}-{{ .Behind }}{{ end }}{{ if .Ahead }}+{{ .Ahead }}{{ end }}{{ end }}{{ if gt .StashCount 0 }} {{ dsl_parentheses "{{ .StashCount }} stashed" }}{{ end }}{{ if .User.Name }} {{ dsl_parentheses "{{ .User.Name }}" }}{{ end }}")" \
    --foreground "white"

# =============================================================================
# PROMPT CHARACTER LINE  
# =============================================================================

dsl_newline
dsl_block "prompt" "left"

# Background job count
dsl_shell \
    "{{ if gt .JobCount 0 }}{{ .JobCount }} {{ end }}" \
    --foreground "white"

# Prompt character (# for root, % for user, colored by exit code)
dsl_exit \
    "{{ if .Root }}# {{ else }}% {{ end }}" \
    --foreground_templates \
        "- '{{ if gt .Code 0 }}error{{ else }}bright_white{{ end }}'"

# =============================================================================
# RIGHT PROMPT (TIME)
# =============================================================================

dsl_rprompt

# Current time (conditional based on setting)
dsl_time \
    "{{ if .Env.BOURGIE_SHOW_TIME }}{{ .CurrentDate | date .Format }}{{ end }}" \
    "15:04:05" \
    --foreground "subtle"