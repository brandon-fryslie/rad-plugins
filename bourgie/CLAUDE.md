# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a zsh theme/plugin called "bourgie" that's part of the rad-plugins collection. The project implements a sophisticated zsh prompt theme with oh-my-posh integration.

## Architecture

The project consists of two main components:

1. **bourgie.plugin.zsh** - Contains custom zsh functions and utilities needed to support the theme
2. **posh-config.yaml** - Oh-my-posh configuration that implements the visual styling and prompt structure

## Theme Features

The bourgie theme implements a comprehensive prompt system with:

- **Git integration**: Shows branch, commit hash, staged/unstaged changes, ahead/behind counts, stash count, and local git username
- **Environment indicators**: Docker host status, Node.js/npm versions, Python virtual environment status
- **Directory display**: Current path with write permission indication
- **SSH awareness**: Different styling and username@hostname display when in SSH sessions
- **Multi-line prompt**: Information line, git status line, and command prompt line

## Key Functions (from AGENT.md specification)

The original zsh theme includes these critical functions that need oh-my-posh equivalents:

- `+vi-git-st()` - Shows remote tracking and ahead/behind counts
- `+vi-git-stash()` - Displays stash count
- `+vi-git-username()` - Shows local git user.name
- `_get-docker-prompt()` - Docker host information with 🐳 icon
- `_get-node-prompt()` - Node.js and npm version display with ⬢ icon  
- `_get-venv-prompt()` - Python virtual environment with 🐱 icon
- `_get-current-dir-prompt()` - Directory path with SSH user@host prefix

## Environment Variables

- `GITTACULOUS_ENABLE_SSH_THEME` - Enables SSH-specific styling
- `ENABLE_DOCKER_PROMPT` - Shows Docker environment info
- `ENABLE_NODE_PROMPT` - Shows Node.js version info
- `LAZY_NODE_PROMPT` - Shows Node info only when nvm is loaded

## Development Workflow

1. Modify `posh-config.yaml` to implement oh-my-posh segments matching the zsh theme functionality
2. Add any required custom functions to `bourgie.plugin.zsh`
3. Test the theme by sourcing the plugin and applying the oh-my-posh config
4. Ensure all original theme features are preserved with improved styling

## Color Scheme Notes

The original theme uses:
- Green for staged changes and positive indicators
- Red for unstaged changes and negative indicators  
- Cyan for Docker prompts
- Yellow for npm versions
- Orange (208) for virtual environments
- Black/white for general text and SSH themes

The oh-my-posh implementation should enhance these with "gorgeous subtle and tasteful colors and organization" as specified in AGENT.md.