#!/usr/bin/env zsh

# Advanced Theme DSL Example
# Demonstrates complex configurations with custom styling

dsl_init

# Define a custom color scheme
dsl_add_color "neon_blue" "#00FFFF"
dsl_add_color "neon_pink" "#FF00FF" 
dsl_add_color "neon_green" "#00FF00"
dsl_add_color "dark_bg" "#1A1A1A"

# =============================================================================
# SYSTEM STATUS LINE
# =============================================================================

dsl_block "prompt" "left"

# System load (custom text segment)
dsl_text \
    "$(dsl_when ".Env.SHOW_SYSTEM_LOAD" "⚡ {{ .Env.SYSTEM_LOAD }} ")" \
    --foreground "neon_blue"

# Memory usage
dsl_text \
    "$(dsl_when ".Env.SHOW_MEMORY" "🧠 {{ .Env.MEMORY_USAGE }}% ")" \
    --foreground "neon_pink"

# Kubernetes context
dsl_text \
    "$(dsl_when ".Env.KUBE_CONTEXT" "☸️ {{ .Env.KUBE_CONTEXT }} ")" \
    --foreground "neon_green"

# =============================================================================
# DEVELOPMENT ENVIRONMENT LINE
# =============================================================================

dsl_newline
dsl_block "prompt" "left"

# Project directory with custom styling
dsl_path \
    "$(dsl_with_icon "📁" "{{ .Path }}") " \
    --style "full" \
    --foreground "cyan"

# Multiple language versions
dsl_node \
    "$(dsl_if_node "$(dsl_with_icon "⬢" "{{ .Major }}.{{ .Minor }}") ")" \
    --foreground "green"

dsl_python \
    "$(dsl_if_venv "$(dsl_with_icon "🐍" "{{ .Major }}.{{ .Minor }}") ")" \
    --foreground "yellow"

# Custom segment for Go version
dsl_text \
    "$(dsl_when ".Env.GO_VERSION" "$(dsl_with_icon "🐹" "{{ .Env.GO_VERSION }}") ")" \
    --foreground "blue"

# =============================================================================
# ADVANCED GIT LINE
# =============================================================================

dsl_newline
dsl_block "prompt" "left"

# Detailed git status with custom formatting
dsl_git \
    "$(dsl_if_git "
$(dsl_with_icon "🌿" "{{ .HEAD }}")
{{ if .Working.Changed }}$(dsl_with_icon "📝" "{{ .Working.Changed }}"){{ end }}
{{ if .Staging.Changed }}$(dsl_with_icon "📦" "{{ .Staging.Changed }}"){{ end }}
{{ if .Upstream }}$(dsl_brackets "{{ .Upstream }}{{ if .Behind }}↓{{ .Behind }}{{ end }}{{ if .Ahead }}↑{{ .Ahead }}{{ end }}"){{ end }}
{{ if gt .StashCount 0 }}$(dsl_with_icon "📚" "{{ .StashCount }}"){{ end }}
")" \
    --foreground "white" \
    --background "dark_bg"

# =============================================================================
# CONDITIONAL ALERTS LINE
# =============================================================================

dsl_newline
dsl_block "prompt" "left"

# Show alerts/warnings
dsl_text \
    "$(dsl_when ".Env.BUILD_FAILED" "$(dsl_with_icon "💥" "Build Failed") ")" \
    --foreground "error"

dsl_text \
    "$(dsl_when ".Env.TESTS_FAILING" "$(dsl_with_icon "🚨" "{{ .Env.FAILING_TESTS }} tests failing") ")" \
    --foreground "warning"

dsl_text \
    "$(dsl_when ".Env.SECURITY_ALERT" "$(dsl_with_icon "🔐" "Security Alert") ")" \
    --foreground "error"

# =============================================================================
# COMMAND LINE
# =============================================================================

dsl_newline
dsl_block "prompt" "left"

# Execution time for last command
dsl_text \
    "$(dsl_when ".Env.LAST_COMMAND_TIME" "$(dsl_with_icon "⏱️" "{{ .Env.LAST_COMMAND_TIME }}ms") ")" \
    --foreground "subtle"

# Enhanced prompt character with background jobs
dsl_shell \
    "{{ if gt .JobCount 0 }}$(dsl_brackets "{{ .JobCount }}") {{ end }}" \
    --foreground "yellow"

# Multi-character prompt
dsl_exit \
    "{{ if .Root }}$(dsl_with_icon "👑" "#"){{ else }}$(dsl_with_icon "⚡" "❯"){{ end }} " \
    --foreground_templates \
        "- '{{ if gt .Code 0 }}error{{ else }}neon_blue{{ end }}'"

# =============================================================================
# RIGHT PROMPT WITH MULTIPLE ELEMENTS
# =============================================================================

dsl_rprompt

# Git user email (for tracking commits)
dsl_git \
    "$(dsl_if_git "{{ if .User.Email }}$(dsl_with_icon "✉️" "{{ .User.Email }}") {{ end }}")" \
    --foreground "subtle"

# Current time with custom format
dsl_time \
    "$(dsl_when ".Env.BOURGIE_SHOW_TIME" "$(dsl_with_icon "🕐" "{{ .CurrentDate | date .Format }}")")" \
    "15:04" \
    --foreground "subtle"

# Session indicator
dsl_session \
    "$(dsl_if_ssh "$(dsl_with_icon "🔗" "SSH")")" \
    --foreground "neon_pink"