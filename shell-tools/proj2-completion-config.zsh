# Optional: Enhanced fuzzy completion configuration for proj2/p2
#
# Source this file in your .zshrc for even better fuzzy matching:
#   source "${0:a:h}/proj2-completion-config.zsh"
#
# Or add these lines directly to your .zshrc

# Enable advanced substring matching for all completions
# This allows matching from anywhere in the string
#
# Matcher list explanation:
#   m:{a-zA-Z}={A-Za-z}  - case insensitive matching
#   r:|[._-]=* r:|=*     - partial word matching (matches after . _ -)
#   l:|=* r:|=*          - substring matching from anywhere
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=* l:|=*'

# Optionally, enable menu selection for easier navigation through matches
zstyle ':completion:*' menu select

# Group matches by type
zstyle ':completion:*' group-name ''

# Use colors in completion menu (if you have a color-capable terminal)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Show descriptions for completions
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'

# For proj2 specifically, you can customize the group names
zstyle ':completion:*:*:proj2:*:*' group-name projects
zstyle ':completion:*:*:p2:*:*' group-name projects
