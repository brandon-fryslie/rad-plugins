# Command Footer
#
# Replaces the off-by-one colored prompt arrow with a footer line that
# describes the just-completed command — exit code and duration. The
# footer is rendered as part of PROMPT (a P10k custom segment), so:
#
#   - It survives Ctrl-L / clear-screen redraws.
#   - It is included in the transient-prompt collapse: prior commands
#     leave the footer line + `❯ command` line in scrollback. Status
#     info is preserved per command without baking color into the arrow
#     before the command has had a chance to run.
#
# Visual shape per command boundary (live prompt at the bottom):
#
#     ╭─❮ ✓ exit=0 • 234ms ─────────────────────────...─────────────╯
#     ❯ command_A
#     <command output>
#     ╭─❮ ✘ exit=1 • 1.70s ─────────────────────────...─────────────╯
#     ❯ command_B
#     <command output>
#     ╭─❮ ✓ exit=0 • 12ms ──────────────────────────...─────────────╯
#     ├─~/code/cc-jstream  feature/branch ──────────...─── 14:23:01
#     ╰─❯ <cursor>
#
# The arrow on the input line carries no status semantics — that lives
# in the footer above where it can actually be correct.

# Re-enable P10k's transient prompt: prior accepted prompts collapse to
# their minimal form in scrollback. We pin the cmd_footer segments
# visible during transient (see below) so the footer line survives.
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir

zmodload zsh/datetime 2>/dev/null

autoload -Uz add-zsh-hook

# Captures command start time so the footer can report duration.
function _rad_p10k_footer_preexec() {
  typeset -gF _RAD_P10K_CMD_START=$EPOCHREALTIME
}

# Computes footer content from the just-completed command's exit status
# and duration, stashes it in _RAD_P10K_FOOTER_TEXT for the segment
# functions to render. Skips when there was no preceding command.
function _rad_p10k_footer_precmd() {
  local last_status=$?

  if [[ -z $_RAD_P10K_CMD_START ]]; then
    unset _RAD_P10K_FOOTER_TEXT
    return 0
  fi

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

  typeset -g _RAD_P10K_FOOTER_TEXT="❮ %F{$status_color}${status_glyph}%f %F{248}exit=${last_status} • ${elapsed_str}%f"
}

add-zsh-hook preexec _rad_p10k_footer_preexec
add-zsh-hook precmd  _rad_p10k_footer_precmd

# Custom P10k segment: footer summary. Renders nothing when there is no
# preceding command (start of session, bare Enter on empty input).
function prompt_cmd_footer() {
  [[ -z $_RAD_P10K_FOOTER_TEXT ]] && return
  p10k segment -f 240 -t "$_RAD_P10K_FOOTER_TEXT"
}

# Custom P10k segment: footer right-end cap. The 180° rotation of the
# top-left corner (╭) used by P10k's first-line prefix. Together with the
# em-dash gap fill in between, this gives us `╭─footer─...─╯` on line 1.
function prompt_cmd_footer_cap() {
  [[ -z $_RAD_P10K_FOOTER_TEXT ]] && return
  p10k segment -f 240 -t '╯'
}
