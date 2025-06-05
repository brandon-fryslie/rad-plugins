# Shell-GPT integration ZSH v0.3
_sgpt_zsh() {
  [[ -z "${BUFFER}" ]] && return 0

  local _sgpt_prompt="$BUFFER"

  # Save original prompt to history (in-memory only, not executed)
  print -s -- "@$_sgpt_prompt" # strip '# prompt: ' from the beginning of this variable, if it exists

  # Optional: persist to history file immediately
  fc -W

  # Show placeholder and refresh UI
  BUFFER="$_sgpt_prompt ⌛"
  zle -I && zle redisplay

  # Replace buffer with AI-generated command
  BUFFER=$(sgpt --shell <<< "$_sgpt_prompt" --no-interaction)

  # Move cursor to end of new buffer
  zle end-of-line
}
zle -N _sgpt_zsh
bindkey '^[j^[j' _sgpt_zsh  # M-j M-j (Alt+j Alt+j)
