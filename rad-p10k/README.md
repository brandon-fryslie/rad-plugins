# rad-p10k

Opinionated Powerlevel10k configuration with sensible defaults.

## Features

- Modern two-line prompt with nerdfont icons
- Comprehensive segment configurations for 50+ tools/environments
- Custom git formatter with detailed status info (gitstatus-based)
- Command footer (exit status + duration) rendered after each command
- Sensible defaults that work out of the box

## Installation

### With rad-shell/zplug

```zsh
zplug "brandon-fryslie/rad-plugins", use:"rad-p10k/rad-p10k.plugin.zsh"
```

### Manual

Source the plugin after loading powerlevel10k:

```zsh
source /path/to/rad-plugins/rad-p10k/rad-p10k.plugin.zsh
```

## Configuration Structure

```
rad-p10k/
├── rad-p10k.plugin.zsh    # Main plugin entry point
├── config/
│   ├── 00-init.zsh        # Initialization, version check
│   ├── 10-prompt-elements.zsh  # Default LEFT/RIGHT prompt elements
│   ├── 20-prompt-style.zsh     # Visual styling (separators, multiline)
│   ├── 30-git-formatter.zsh    # Custom git status formatter
│   ├── 40-segments.zsh         # All segment color/behavior settings
│   ├── 50-transient.zsh        # Command footer (replaces transient prompt)
│   └── 90-finalize.zsh         # Instant prompt, reload
└── README.md
```

## Customization

rad-p10k provides defaults that can be overridden in your personal config.
Source rad-p10k first, then override any settings:

```zsh
# In your personal p10k config:
source "${RAD_PLUGINS_DIR}/rad-p10k/rad-p10k.plugin.zsh"

# Override prompt elements
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  dir
  vcs
  newline
  prompt_char
)

# Override any other settings...
typeset -g POWERLEVEL9K_DIR_FOREGROUND=39
```

## Git Status

rad-p10k includes a custom `my_git_formatter` function that provides:

- Branch name with smart truncation (32 chars max)
- Commits ahead/behind remote with color coding
- Remote tracking branch display
- Staged/unstaged/untracked indicators
- WIP detection in commit messages
- Push status (ahead/behind push remote)
- Merge/rebase state
- Stash count

## Command Footer

After each command, a two-line footer is printed before the next prompt:

```
<command output>
─────────────────────────────────────────────────────────────────...─
╰─❮ ✓ exit=0 • 234ms

╭─~/code/cc-jstream  branch ───────...─── 14:23:01
╰─❯ next_command
```

The footer fires from `precmd`, so `$?` and the elapsed time are the
real values for the command that just ran — unlike a traditional
transient prompt, which has to redraw before the command runs and can
only reflect the *previous* command's status.

The arrow on the user-input line is intentionally neutral; status info
lives in the footer where it can be correct.

P10k's built-in transient prompt is disabled (`POWERLEVEL9K_TRANSIENT_PROMPT=off`)
because the two mechanisms conflict.

The footer is suppressed for the first prompt of a session and for
empty-Enter on a blank input line (no command actually ran in those
cases, so there is nothing to report).

## Dependencies

- [powerlevel10k](https://github.com/romkatv/powerlevel10k)
- Nerd Font for icons (recommended: JetBrainsMono Nerd Font)
