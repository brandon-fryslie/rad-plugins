#!/usr/bin/env zsh

# Simple Theme DSL Example
# Demonstrates minimal configuration with clean syntax

dsl_init

# Simple single-line prompt
dsl_block

# Show directory
dsl_path "{{ .Path }} " --foreground "cyan"

# Show git branch if in repo
dsl_git \
    "$(dsl_if_git "$(dsl_parentheses "{{ .HEAD }}")") ")" \
    --foreground "green"

# Simple prompt character
dsl_text "❯ " --foreground "blue"