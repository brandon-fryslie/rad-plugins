# Command Footer
#
# Replaces P10k's transient prompt with a "footer" rendered after each
# command finishes. A traditional transient prompt is drawn at
# zle-line-finish (before the command runs), so the colored exit-status
# arrow can only reflect the *previous* command's status — which produces
# an off-by-one in scrollback. Drawing instead at precmd (after the
# command returns) inverts the data dependency: every fact in the footer
# is known at render time, including exit code and duration.
#
# Visual shape per command boundary:
#
#     <command output>
#     ──────────────────────────────────────────────────...─
#     ╰─❮ ✓ exit=0 • 234ms
#
#     ╭─~/code/cc-jstream  branch ───────────...─── 14:23:01
#     ╰─❯ next_command
#
# The arrow on the user-input line is intentionally neutral — all
# status semantics live in the footer above it, where they are correct.

# P10k's built-in transient prompt is incompatible with this model.
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=off

# High-resolution time, for command duration. P10k loads this too, but
# load it explicitly so this file is self-contained.
zmodload zsh/datetime 2>/dev/null

autoload -Uz add-zsh-hook

# Captures command start time. Fires after Enter is accepted, before the
# command runs. If the user submits a bare empty line, preexec does NOT
# fire — that's how the precmd hook below knows to skip the footer.
function _rad_p10k_footer_preexec() {
  typeset -gF _RAD_P10K_CMD_START=$EPOCHREALTIME
}

# Renders the footer for the just-completed command. Fires after the
# command returns, before the next prompt is drawn.
function _rad_p10k_footer_precmd() {
  local last_status=$?

  # No preceding command (start of session, or bare Enter on empty input):
  # nothing to report on, skip the footer entirely.
  [[ -n $_RAD_P10K_CMD_START ]] || return 0

  local elapsed_s=$(( EPOCHREALTIME - _RAD_P10K_CMD_START ))
  unset _RAD_P10K_CMD_START

  local -i elapsed_total_s=$elapsed_s
  local elapsed_str
  if (( elapsed_s < 1 )); then
    local -i ms=$(( elapsed_s * 1000 ))
    elapsed_str="${ms}ms"
  elif (( elapsed_s < 60 )); then
    elapsed_str="$(printf '%.2f' $elapsed_s)s"
  elif (( elapsed_total_s < 3600 )); then
    elapsed_str="$(( elapsed_total_s / 60 ))m$(( elapsed_total_s % 60 ))s"
  else
    elapsed_str="$(( elapsed_total_s / 3600 ))h$(( (elapsed_total_s / 60) % 60 ))m"
  fi

  local status_glyph status_color
  if (( last_status == 0 )); then
    status_glyph='✓'
    status_color=70   # green
  else
    status_glyph='✘'
    status_color=160  # red
  fi

  local divider_color=240
  local meta_color=248
  local cols=${COLUMNS:-80}

  print -P "%F{$divider_color}${(l:cols::─:)}%f"
  print -P "%F{$divider_color}╰─%f%F{$status_color}${status_glyph}%f %F{$meta_color}exit=${last_status} • ${elapsed_str}%f"
}

add-zsh-hook preexec _rad_p10k_footer_preexec
add-zsh-hook precmd  _rad_p10k_footer_precmd
