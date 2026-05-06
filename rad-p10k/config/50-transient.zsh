# Command Footer
#
# Renders a footer line above each command in scrollback describing the
# just-completed command (exit status, duration). Visual shape per
# command boundary, with the live (typing) prompt at the bottom:
#
#     ╰─❮ ✓ exit=0 • 234ms ─────────────────────────...──────────────
#     ❯ command_A
#     <command output>
#     ╰─❮ ✘ exit=1 • 1.70s ─────────────────────────...──────────────
#     ❯ command_B
#     <command output>
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
#   The footer lives ONLY in the transient (collapsed-into-scrollback)
#   prompt — not in the live prompt. Why one surface only: a footer in
#   the live prompt produces a visible duplicate row in scrollback
#   (one from the live prompt's own first line, one from the next
#   command's transient swap). Concentrating it in transient gives
#   exactly one footer line per command boundary.
#
#   P10k builds _p9k_transient_prompt once at init as a hardcoded
#   ❯-only string (internal/p10k.zsh:8585-8614). It does NOT consult
#   per-segment TRANSIENT_* overrides for custom segments. But P10k
#   calls the p10k-on-post-prompt hook on every zle-line-finish, just
#   before the transient swap (line 7887), so we use that hook to
#   mutate _p9k_transient_prompt right before P10k reads it.
#
#   Trade-off: Ctrl-L on the live prompt does not redraw the footer
#   (it lives in scrollback, not in PROMPT). Most terminals preserve
#   scrollback across Ctrl-L, so the footer remains reachable by
#   scrolling up.

typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir

zmodload zsh/datetime 2>/dev/null

autoload -Uz add-zsh-hook

# Captures command start time. Fires after Enter, before the command runs.
function _rad_p10k_footer_preexec() {
  typeset -gF _RAD_P10K_CMD_START=$EPOCHREALTIME
}

# Computes footer text from the just-finished command's exit code and
# elapsed time, and stores TWO versions:
#   - _RAD_P10K_FOOTER_TEXT      (with %F{N}%f color escapes, for display)
#   - _RAD_P10K_FOOTER_TEXT_RAW  (no color escapes, for visible-width math)
# Skipped when no command actually ran (start of session, bare Enter).
function _rad_p10k_footer_precmd() {
  local last_status=$?

  if [[ -z $_RAD_P10K_CMD_START ]]; then
    unset _RAD_P10K_FOOTER_TEXT _RAD_P10K_FOOTER_TEXT_RAW
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
  typeset -g _RAD_P10K_FOOTER_TEXT_RAW="❮ ${status_glyph} exit=${last_status} • ${elapsed_str}"
}

add-zsh-hook preexec _rad_p10k_footer_preexec
add-zsh-hook precmd  _rad_p10k_footer_precmd

# Hook called by P10k from zle-line-finish (internal/p10k.zsh:7887),
# just before the transient prompt swap at 7910. Mutating
# _p9k_transient_prompt here lets us replace the hardcoded `❯` with
# `<footer line>\n❯` so the footer survives the collapse into scrollback.
#
# We cache P10k's original transient string on first call so we don't
# accumulate footers across invocations.
function p10k-on-post-prompt() {
  [[ -z $_p9k_transient_prompt ]] && return

  if [[ -z $_RAD_P9K_TRANSIENT_ORIG ]]; then
    typeset -g _RAD_P9K_TRANSIENT_ORIG=$_p9k_transient_prompt
  fi

  if [[ -z $_RAD_P10K_FOOTER_TEXT ]]; then
    _p9k_transient_prompt=$_RAD_P9K_TRANSIENT_ORIG
    return
  fi

  # Layout: ╰─ + footer_text + ' ' + N×─    (no end cap; dashes flow to edge)
  # ╰, ─, ❮, ✓, ✘ are all single-cell-width Unicode in any reasonable terminal.
  local -i text_cells=$#_RAD_P10K_FOOTER_TEXT_RAW
  local -i prefix_cells=2  # "╰─"
  local -i sep_cells=1     # space before dashes
  local -i dash_count=$(( COLUMNS - prefix_cells - text_cells - sep_cells ))
  (( dash_count < 0 )) && dash_count=0

  local _empty=
  local dashes=${(l:dash_count::─:)_empty}

  local footer_line=$'%F{240}╰─%f'${_RAD_P10K_FOOTER_TEXT}$' %F{240}'${dashes}$'%f\n'

  _p9k_transient_prompt="${footer_line}${_RAD_P9K_TRANSIENT_ORIG}"
}
