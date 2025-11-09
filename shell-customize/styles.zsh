# Colors
export CLICOLOR=1
export LSCOLORS=gxfxcxdxbxegedabagacad

zstyle ':prezto:*:*' color 'yes'
zstyle ':completion:*:default' list-colors ''

# Configure the syntax highlighter a little
if typeset -p ZSH_HIGHLIGHT_HIGHLIGHTERS > /dev/null 2>&1; then
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern cursor)
  ZSH_HIGHLIGHT_STYLES[globbing]='fg=blue,bold'
  ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=blue,bold'
  ZSH_HIGHLIGHT_STYLES[bracket-error]='fg=red,bold,underline'
  ZSH_HIGHLIGHT_PATTERNS+=('$[a-zA-Z0-9_]#' 'fg=cyan,underline') # Shell variables
fi
