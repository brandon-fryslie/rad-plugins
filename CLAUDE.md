# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Zsh plugins for the rad-shell framework. The rad-shell framework is a feature-rich shell environment built on Zsh, Prezto, and Zgenom (a fork of Zgen). These plugins provide additional functionality and features for the shell environment.

## Testing

```bash
# Run proj2 tests
./shell-tools/tests/proj2/run_tests.sh

# Run ZUnit tests (requires zunit installed: brew install zunit)
./run_tests.sh
```

To test plugin changes interactively:
```bash
source /path/to/plugin/plugin-name.plugin.zsh
# Or reload entire config
source ~/.zshrc
```

## Architecture

### Plugin Loading
- Plugins loaded via `~/.rad-plugins` file by the rad-shell framework
- Deferred initialization: plugins register hooks via `rad_plugin_init_hooks+=("hook_name:${script_dir}")`
- Dependency declarations use `# ☢ depends_on <plugin_id>` or `# @rad@ depends_on <plugin_id>` format

### Zaw Integration Pattern
Zaw provides filterable lists (like Emacs Helm). Plugins integrate via `*-zaw.zsh` files:
- Register sources with `zaw-register-src -n <name> <source-function>`
- Use `zaw-rad-buffer-action` for actions that modify the command buffer
- Key bindings defined in `zaw/zaw.plugin.zsh`

### Project Navigation (proj/proj2)
Two project navigation systems in `shell-tools/`:
- `proj.zsh` - Simple completion-based navigation using `PROJECTS_DIRS` array
- `proj2.zsh` - fzf-based selector with git status, tmux integration, preview pane

### Key Plugins
| Plugin | Purpose |
|--------|---------|
| `shell-tools` | Core utilities: proj/proj2, cdtl, exec-find, find-zsh-sources |
| `git` | Git aliases, gh-open, really-really-amend, zaw sources for git |
| `zaw` | Zaw configuration, key bindings, utility functions |
| `shell-customize` | History config, colors, syntax highlighting |

## Coding Conventions

- Prefix shared functions with `rad-` to avoid namespace conflicts
- Use `${0:a:h}` pattern to get script directory
- Quote variables: use `"$var"` not `$var` (handles paths with spaces)
- For external scripts, capture plugin dir at load time: `typeset -g MY_PLUGIN_DIR="${0:a:h}"`