# Command Footer
#
# Prints a footer line above the next prompt summarizing the just-
# completed command (exit status, duration). Visual shape per command
# boundary, with the live (typing) prompt below:
#
#     ╰─❮ ✓ exit=0 • 234ms ─────────────────────────...──────────────
#     ╭─~/code/cc-jstream  feature/branch ──────────...─── 14:23:01
#     ╰─❯ <cursor>
#
# WHY:
#   A traditional transient prompt is drawn at zle-line-finish — *before*
#   the command runs. Its colored arrow can therefore only ever reflect
#   the *previous* command's exit status, producing a quiet off-by-one
#   in scrollback. The footer is rendered after the command returns,
#   from data the renderer actually has at that moment.
#
# HOW:
#   precmd computes the footer text and `print -P`s it directly. The
#   line lands in scrollback once, unconditionally, before P10k draws
#   its prompt below it. No PROMPT mutation, no transient hooks, no
#   coordination — the dataflow is: cmd ends → precmd → print → done.
#   Earlier attempts mutated _p9k_transient_prompt via P10k's
#   p10k-on-post-prompt hook; that produced duplicate footers in
#   scrollback because the transient redraw didn't fully overwrite
#   the live prompt. Print-from-precmd sidesteps the entire mechanism.

zmodload zsh/datetime 2>/dev/null

autoload -Uz add-zsh-hook

# Captures command start time. Fires after Enter, before the command runs.
function _rad_p10k_footer_preexec() {
  typeset -gF _RAD_P10K_CMD_START=$EPOCHREALTIME
}

# Computes footer text from the just-finished command's exit code and
# elapsed time, then prints it. Skipped when no command actually ran
# (start of session, bare Enter).
function _rad_p10k_footer_precmd() {
  local last_status=$?

  [[ -z $_RAD_P10K_CMD_START ]] && return 0

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

  local footer_text="❮ %F{$status_color}${status_glyph}%f %F{248}exit=${last_status} • ${elapsed_str}%f"
  local footer_text_raw="❮ ${status_glyph} exit=${last_status} • ${elapsed_str}"

  # Layout: ╰─ + footer_text + ' ' + N×─    (no end cap; dashes flow to edge)
  local -i text_cells=$#footer_text_raw
  local -i prefix_cells=2  # "╰─"
  local -i sep_cells=1
  local -i dash_count=$(( COLUMNS - prefix_cells - text_cells - sep_cells ))
  (( dash_count < 0 )) && dash_count=0
  local _empty=
  local dashes=${(l:dash_count::─:)_empty}

  print -P -- "%F{240}╰─%f${footer_text} %F{240}${dashes}%f"
}

add-zsh-hook preexec _rad_p10k_footer_preexec
add-zsh-hook precmd  _rad_p10k_footer_precmd
