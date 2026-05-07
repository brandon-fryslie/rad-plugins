# Command Footer
#
# Prints a footer line above the next prompt summarizing the just-
# completed command (exit status, duration). Visual shape per command
# boundary, with the live (typing) prompt below:
#
#     ╰─❮ 14:23:01 • 234ms • ~/code/cc-jstream • git ❯──────...─────
#     ╭─~/code/cc-jstream  feature/branch ──────────...─── 14:23:01
#     ╰─❯ <cursor>
#
# The ❮ glyph is colored green on success and red on non-zero exit —
# that's the entire status indicator (no glyph, no numeric exit code).
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

# Re-enable P10k's transient prompt feature (collapses prior prompts to
# a short form on Enter). Independent of the footer — the footer is
# plain scrollback text printed by precmd; transient operates on PROMPT.
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir

zmodload zsh/datetime 2>/dev/null

autoload -Uz add-zsh-hook

# Captures command start time and the command name (first word of the
# command line as typed). Fires after Enter, before the command runs.
function _rad_p10k_footer_preexec() {
  typeset -gF _RAD_P10K_CMD_START=$EPOCHREALTIME
  typeset -g _RAD_P10K_CMD_NAME=${1%% *}
}

# Computes footer text from the just-finished command's exit code and
# elapsed time, then prints it. Skipped when no command actually ran
# (start of session, bare Enter).
function _rad_p10k_footer_precmd() {
  local last_status=$?

  [[ -z $_RAD_P10K_CMD_START ]] && return 0

  local elapsed_s=$(( EPOCHREALTIME - _RAD_P10K_CMD_START ))
  local cmd_name=$_RAD_P10K_CMD_NAME
  unset _RAD_P10K_CMD_START _RAD_P10K_CMD_NAME

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

  # The ❮ glyph itself carries the exit-status signal: green for 0,
  # red for non-zero. No separate glyph or numeric exit code in the line.
  local status_color=70   # green
  (( last_status != 0 )) && status_color=160  # red

  # cwd with ~ collapse, expanded via prompt-escape so we get the real
  # string for both display and width math (no double-expansion later).
  local cwd=${(%):-%~}
  # Timestamp at footer-print time (when the command finished, not started).
  local timestamp=${(%):-%D{%H:%M:%S}}

  # Per-field colors — muted to match the timestamp's teal saturation.
  #   timestamp = 66  (TIME_FOREGROUND, muted teal)
  #   duration  = 100 (dim olive-yellow)
  #   cwd       = 31  (DIR_FOREGROUND, blue)
  #   cmd_name  = 65  (sage green — dimmer than VCS-clean's 76)
  # Separator dot stays dim (240) so it recedes visually.
  local sep='%F{240}•%f'
  local footer_text="%F{$status_color}❮%f %F{66}${timestamp}%f ${sep} %F{100}${elapsed_str}%f ${sep} %F{31}${cwd}%f ${sep} %F{65}${cmd_name}%f"
  local footer_text_raw="❮ ${timestamp} • ${elapsed_str} • ${cwd} • ${cmd_name}"

  # Layout: ╰─ + footer_text + ' ❯' + N×─    (gray ❯ butts up to the dashes)
  # The ❯ is the same gray (244) as the live PROMPT_CHAR — visual rhyme
  # between the footer and the live prompt below.
  local -i text_cells=$#footer_text_raw
  local -i prefix_cells=2  # "╰─"
  local -i sep_cells=2     # " ❯"
  local -i dash_count=$(( COLUMNS - prefix_cells - text_cells - sep_cells ))
  (( dash_count < 0 )) && dash_count=0
  local _empty=
  local dashes=${(l:dash_count::─:)_empty}

  print -P -- "%F{240}╰─%f${footer_text} %F{244}❯%f%F{240}${dashes}%f"
}

add-zsh-hook preexec _rad_p10k_footer_preexec
add-zsh-hook precmd  _rad_p10k_footer_precmd
