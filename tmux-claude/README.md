# Tmux-Claude Integration Plugin

A comprehensive integration plugin for using [Claude Code CLI](https://claude.ai/code) with [tmux](https://github.com/tmux/tmux). This plugin provides convenient commands, layouts, and interactive selectors for managing Claude Code sessions within tmux.

## Features

- **Easy Claude Code Launching**: Quick commands to start Claude Code in new panes, windows, or sessions
- **Pre-configured Layouts**: Common development layouts with Claude Code integration
- **FZF Interactive Selectors**: Beautiful, keyboard-driven selectors for tmux sessions, windows, and panes
- **Content Sharing**: Send files, text, or captured output to Claude Code running in another pane
- **Smart Navigation**: Jump to Claude Code panes automatically
- **Extensive Aliases**: Short, memorable aliases for all common operations

## Requirements

- Zsh
- tmux
- [Claude Code CLI](https://claude.ai/code)
- [fzf](https://github.com/junegunn/fzf) (for interactive selectors)

## Installation

Add the plugin to your `~/.rad-plugins` file:

```bash
echo "brandon-fryslie/rad-plugins tmux-claude" >> ~/.rad-plugins
```

Then reload your shell or run:

```bash
source ~/.zshrc
```

## Quick Start

```bash
# Split current pane and start Claude Code
tc

# Create side-by-side layout
tcls

# Interactive pane selector
tsp

# Interactive session selector
tss

# Show help
tc-help
```

## Commands Reference

### Starting Claude Code

| Command | Alias | Description |
|---------|-------|-------------|
| `claude-split [dir]` | `tc` | Split pane horizontally and start Claude Code |
| `claude-vsplit [dir]` | `tcv` | Split pane vertically and start Claude Code |
| `claude-window [dir] [name]` | `tcw` | Create new window with Claude Code |
| `claude-session [name] [dir]` | `tcs` | Create new tmux session with Claude Code |

### Layouts

| Command | Alias | Description |
|---------|-------|-------------|
| `claude-layout-sidebyside [dir]` | `tcls` | Side-by-side: shell \| Claude Code |
| `claude-layout-stack [dir]` | `tclk` | Stacked: Claude Code (top) \| shell (bottom) |
| `claude-layout-three [dir]` | `tcl3` | Three panes: shell \| Claude Code \| output |

### Sending Content to Claude

| Command | Description |
|---------|-------------|
| `claude-send-keys <pane> <text>` | Send text/command to Claude Code pane |
| `claude-send-file <pane> <file>` | Send file path to Claude Code for analysis |
| `claude-capture <src> <dst> [lines]` | Capture output from source pane, send to Claude |

### FZF Interactive Selectors

| Command | Alias | Description |
|---------|-------|-------------|
| `claude-select-session` | `tss` | Interactive session selector with actions |
| `claude-select-pane` | `tsp` | Interactive pane selector with actions |
| `claude-select-window` | `tsw` | Interactive window selector with actions |
| `claude-send-to-pane` | `tcsp` | Select pane and send text to it |

#### Session Selector (`tss`) Actions

- **Enter**: Attach/switch to session
- **Ctrl-K**: Kill session
- **Ctrl-D**: Kill all other sessions
- **Preview**: Shows windows in session

#### Pane Selector (`tsp`) Actions

- **Enter**: Switch to pane
- **Ctrl-C**: Capture and view pane output in less
- **Ctrl-K**: Kill pane
- **Ctrl-Y**: Copy pane ID to clipboard
- **Preview**: Shows pane content

#### Window Selector (`tsw`) Actions

- **Enter**: Switch to window
- **Ctrl-K**: Kill window
- **Preview**: Shows panes in window

### Navigation & Utilities

| Command | Alias | Description |
|---------|-------|-------------|
| `claude-list-panes` | `tcl` | List all tmux panes with IDs |
| `claude-find-pane` | `tcf` | Find panes running Claude Code |
| `claude-goto` | `tcg` | Jump to Claude Code pane |
| `tmux-claude-help` | `tc-help` | Show help information |

## Usage Examples

### Basic Usage

```bash
# Start Claude Code in a horizontal split
tc

# Start Claude Code in a specific directory
tc ~/projects/myapp

# Create a new window named "ai-assistant" with Claude Code
tcw myapp ai-assistant

# Create a new session dedicated to Claude Code
tcs my-claude-session ~/projects
```

### Layout Examples

```bash
# Side-by-side layout: perfect for code + AI assistance
tcls

# Stacked layout: Claude on top (70%), shell below (30%)
tclk

# Three-pane layout: shell | Claude | logs/output
tcl3
```

### Interactive Selection

```bash
# Select and switch between tmux sessions
tss

# Select and switch to any pane (with preview)
tsp

# Send text to a selected pane
tcsp
```

### Sending Content to Claude

```bash
# Send a file to Claude Code in pane %2
claude-send-file %2 src/app.js

# Send text/command to Claude Code
claude-send-keys %2 "Explain this error message"

# Capture last 100 lines from pane %1 and send to Claude in pane %2
claude-capture %1 %2 100
```

### Finding and Navigating Claude Panes

```bash
# List all panes with their IDs
tcl

# Find which panes are running Claude Code
tcf

# Jump to Claude Code pane automatically
tcg
```

## Workflow Examples

### Development Workflow

1. Start a side-by-side layout:
   ```bash
   tcls
   ```

2. Use left pane for coding, right pane for Claude Code assistance

3. Send files to Claude for review:
   ```bash
   claude-send-file %2 src/buggy-file.js
   ```

### Debugging Workflow

1. Create three-pane layout:
   ```bash
   tcl3
   ```

2. Left pane: edit code
3. Top-right pane: Claude Code for assistance
4. Bottom-right pane: run your application/tests

5. Capture error output and send to Claude:
   ```bash
   claude-capture %3 %2 50
   ```

### Multi-Project Workflow

1. Create separate sessions for each project:
   ```bash
   tcs project-a ~/work/project-a
   tcs project-b ~/work/project-b
   ```

2. Use `tss` to quickly switch between projects

3. Each session has its own Claude Code instance with proper context

## Tips & Tricks

1. **Pane IDs**: Use `tcl` to see all pane IDs, which you'll need for `claude-send-file` and similar commands.

2. **Quick Access**: The `tcg` command is useful when you have multiple panes open and want to quickly jump back to Claude Code.

3. **Capture for Context**: Use `claude-capture` to send error messages or command output directly to Claude Code for analysis.

4. **FZF Preview**: The preview window in fzf selectors shows you the content of panes/windows before switching, helping you find the right one quickly.

5. **Keyboard-Driven**: All fzf selectors are fully keyboard-driven. Learn the Ctrl-K (kill) and Ctrl-C (capture) shortcuts for faster workflow.

6. **Session Management**: Use `tss` with Ctrl-D to quickly clean up all sessions except the one you're working in.

## Customization

The plugin respects standard color helper functions:
- `rad-red`: Error messages
- `rad-yellow`: Warnings
- `rad-green`: Success messages

You can customize these in your shell configuration if desired.

## Troubleshooting

**"Claude Code CLI not found"**
- Install Claude Code from https://claude.ai/code
- Ensure `claude` is in your PATH

**"fzf is required but not installed"**
- Install fzf: `brew install fzf` (macOS) or check https://github.com/junegunn/fzf

**"Not in a tmux session"**
- Some commands require you to be inside a tmux session
- Start tmux with: `tmux` or `tcs my-session`

**FZF clipboard copy not working**
- The Ctrl-Y binding in `tsp` requires `xclip` (Linux) or `pbcopy` (macOS)
- Install with: `apt install xclip` or already available on macOS

## Contributing

This plugin is part of the [rad-plugins](https://github.com/brandon-fryslie/rad-plugins) repository. Contributions are welcome!

## License

Part of rad-plugins repository. Check the main repository for license information.
