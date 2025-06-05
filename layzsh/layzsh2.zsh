# layzsh — AI Mode Zsh Plugin (Hybrid Model)
# Save this as ~/.zsh/layzsh.plugin.zsh and source it from .zshrc

# --- Global State ---
typeset -g LAYZSH_AGENT_MODE=0
typeset -gA _layzsh_prev_tab_bindings  # Stores previous Tab bindings per keymap
typeset -g _layzsh_original_cursor_color="\e]12;#FFFFFF\a"  # Default cursor color escape sequence

# --- Cursor Color Control ---
_layzsh_cursor_on() {
  print -n "\e]12;#A4FFA4\a"  # Light lime green
}

_layzsh_cursor_off() {
  print -n $_layzsh_original_cursor_color
}

# --- Tab Key Binding Management ---
_layzsh_bind_keys() {
  local km="$KEYMAP"
  _layzsh_prev_tab_bindings[$km]=$(bindkey -M "$km" '^I' 2>/dev/null | awk '{print $2}')
  bindkey -M "$km" '^I' _layzsh_maybe_tab_complete
}

_layzsh_unbind_keys() {
  local km="$KEYMAP"
  if [[ -n ${_layzsh_prev_tab_bindings[$km]} ]]; then
    bindkey -M "$km" '^I' "${_layzsh_prev_tab_bindings[$km]}"
    unset "_layzsh_prev_tab_bindings[$km]"
  fi
}

# --- Enter AI Mode on '@' key ---
function _layzsh_handle_mode_enter_key() {
#  zle_log "[LAYZSH] Handle @ key"
#  if (( LAYZSH_AGENT_MODE )); then
#    return
#  fi
  zle .self-insert
  if (( !LAYZSH_AGENT_MODE )); then
    LAYZSH_AGENT_MODE=1
    _layzsh_cursor_on
    _layzsh_bind_keys
  fi
  zle reset-prompt
}
zle -N _layzsh_handle_mode_enter_key
bindkey -M emacs '@' _layzsh_handle_mode_enter_key

# --- Passive AI Mode Exit Checker ---
function _layzsh_maybe_exit_mode() {
  _zle_log_flush
  if (( LAYZSH_AGENT_MODE )) && [[ $LBUFFER != '@'* ]]; then
    LAYZSH_AGENT_MODE=0
    _layzsh_cursor_off
    _layzsh_unbind_keys
    zle reset-prompt
  fi
}
zle -N _layzsh_maybe_exit_mode
zle -N zle-line-pre-redraw _layzsh_maybe_exit_mode

_layzsh_command_gen() {
  # Save original prompt to history (in-memory only, not executed)
  print -s -- "@command: $_sgpt_prompt" # strip '# prompt: ' from the beginning of this variable, if it exists

  # Optional: persist to history file immediately
  fc -W

  # Show placeholder and refresh UI
  BUFFER="$_sgpt_prompt ⌛"
  zle -I && zle redisplay

  # Replace buffer with AI-generated command
  BUFFER=$(sgpt --shell <<< "$_sgpt_prompt" --no-interaction)
}

_layzsh_command_explain() {
   # Save original prompt to history (in-memory only, not executed)
    print -s -- "@explain: $_sgpt_prompt" # strip '# prompt: ' from the beginning of this variable, if it exists

    # Optional: persist to history file immediately
    fc -W

    # Show placeholder and refresh UI
    BUFFER="$_sgpt_prompt ⌛"
    zle -I && zle redisplay

    # Replace buffer with AI-generated command
    BUFFER=$(sgpt --describe-shell <<< "$_sgpt_prompt")
}

_layzsh_question() {
   # Save original prompt to history (in-memory only, not executed)
    print -s -- "@question: $_sgpt_prompt" # strip '# prompt: ' from the beginning of this variable, if it exists

    # Optional: persist to history file immediately
    fc -W

    # Show placeholder and refresh UI
    BUFFER="$_sgpt_prompt ⌛"
    zle -I && zle redisplay

    # Replace buffer with AI-generated command
    BUFFER=$(sgpt <<< "$_sgpt_prompt")
}

# --- Custom Enter Key ---
function _layzsh_maybe_accept_line() {
  if (( LAYZSH_AGENT_MODE )) && [[ $BUFFER == '@'* ]]; then
    # When and what should we save to history?

    # Dispatch to various functions
    if [[ $BUFFER == '@!?'* ]]; then
      local _sgpt_prompt="$BUFFER"
      _sgpt_prompt="${_sgpt_prompt#@!?}"
      _sgpt_prompt="${_sgpt_prompt##@prompt:}"
      _layzsh_command_gen
      _layzsh_command_explain
    elif [[ $BUFFER == '@!'* ]]; then
      local _sgpt_prompt="$BUFFER"
      _sgpt_prompt="${_sgpt_prompt#@!}"
      _sgpt_prompt="${_sgpt_prompt##@prompt:}"
      _layzsh_command_gen
    elif [[ $BUFFER == '@?'* ]]; then
      local _sgpt_prompt="$BUFFER"
      _sgpt_prompt="${_sgpt_prompt#@?}"
      _sgpt_prompt="${_sgpt_prompt##@prompt:}"
      _layzsh_question
    else
      local _sgpt_prompt="$BUFFER"
      _sgpt_prompt="${_sgpt_prompt#@}"
      _sgpt_prompt="${_sgpt_prompt##@prompt:}"
      _layzsh_question
    fi

      # clean the buffer
      #local _sgpt_prompt="${BUFFER}"
      #_sgpt_prompt="${_sgpt_prompt##@}"
      #_sgpt_prompt="${_sgpt_prompt##@prompt:}"




      # Move cursor to end of new buffer
      zle end-of-line

#    BUFFER=""  # Clear the buffer after processing
#    zle redisplay  # Ensure the prompt is redisplayed correctly
    LAYZSH_AGENT_MODE=0
    _layzsh_cursor_off
    _layzsh_unbind_keys
#    zle reset-prompt
#    zle redisplay  # Ensure the prompt is redisplayed correctly
  else
    zle .accept-line
  fi
}

# --- Consolidated Agent Mode Styling ---
function _layzsh_update_prompt() {
  if (( LAYZSH_AGENT_MODE )); then
    # Store original prompt settings
    if [[ -z $_layzsh_original_prompt ]]; then
      _layzsh_original_prompt="$PROMPT"
      _layzsh_original_rprompt="$RPROMPT"
    fi

    # Add status line to the top of the PROMPT
    PROMPT="%F{yellow}[ Layzsh Agent Mode ]%f\n${_layzsh_original_prompt}"

    # Ensure RPROMPT is reset or adjusted if needed
    RPROMPT="${_layzsh_original_rprompt:-}"
  elif [[ -n $_layzsh_original_prompt ]]; then
    # Restore original prompt settings
    PROMPT="$_layzsh_original_prompt"
    RPROMPT="${_layzsh_original_rprompt:-}"
    unset _layzsh_original_prompt _layzsh_original_rprompt
  fi
}

# Ensure the function is added only once
precmd_functions=(${precmd_functions:#_layzsh_update_prompt})
precmd_functions+=(_layzsh_update_prompt)
zle -N _layzsh_maybe_accept_line
bindkey '^M' _layzsh_maybe_accept_line

# --- Custom Tab Key ---
function _layzsh_maybe_tab_complete() {
  if (( LAYZSH_AGENT_MODE )); then
    print -u2 "[AI] (Stub) Open filterselect menu"
  else
    zle .expand-or-complete
  fi
}
zle -N _layzsh_maybe_tab_complete


# --- Initialize Cursor on Shell Load ---
_layzsh_cursor_off
