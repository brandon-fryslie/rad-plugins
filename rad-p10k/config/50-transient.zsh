# Command Footer
#
# Prints a footer line above the next prompt summarizing the just-
# completed command (exit status, duration). Visual shape per command
# boundary, with the live (typing) prompt below:
#
#     ╰─❮ 2:23:01 PM • 234ms • ~/code/cc-jstream • feature/branch • git ❯──...──
#     ╭─~/code/cc-jstream  feature/branch ──────────...─── 2:23:01 PM
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

# Fits a cwd string into at most `budget` display cells, in the spirit of
# p10k's own dir truncation: leading path components collapse to their first
# character (left to right, last component kept whole) until the path fits;
# if even the fully collapsed path is too long, the tail survives behind a
# leading …. A cwd that already fits passes through unchanged, so at generous
# widths this is the identity. Total for any budget: the floor is a bare "…".
function _rad_p10k_fit_cwd() {
  local cwd=$1
  local -i budget=$2
  # ${(s:/:)} drops empty fields, which would eat an absolute path's leading
  # slash — carry it separately and re-prepend on every rejoin.
  local root=${cwd%%[^/]*}
  local -a parts=( ${(s:/:)cwd} )
  local -i i
  for (( i = 1; i < $#parts && $#cwd > budget; i++ )); do
    parts[i]=${parts[i][1]}
    cwd="${root}${(j:/:)parts}"
  done
  if (( $#cwd > budget )); then
    local -i keep=$(( budget - 1 ))
    (( keep < 0 )) && keep=0
    cwd="…${cwd[$#cwd - keep + 1, -1]}"
  fi
  print -r -- "$cwd"
}

# Assembles the colored footer line and its uncolored width-math twin from
# the segment lists. Dynamic-scope contract (same idiom as my_git_formatter's
# helpers): reads seg_colors, seg_texts, status_color from the caller; writes
# footer_text, footer_text_raw back into it.
# [LAW:one-source-of-truth] one segment list, one assembly, drives both the
# colored line and the raw string used for width math, so the two can't drift.
function _rad_p10k_footer_assemble() {
  local sep='%F{240}•%f'
  footer_text="%F{$status_color}❮%f "
  footer_text_raw='❮ '
  local -i i n=0
  for (( i = 1; i <= $#seg_texts; i++ )); do
    [[ -n ${seg_texts[i]} ]] || continue
    (( n++ )) && { footer_text+=" ${sep} "; footer_text_raw+=' • '; }
    # % → %% so print -P shows branch/path/command text literally instead of
    # re-expanding it as prompt escapes; the raw string keeps the unescaped
    # text since %% renders as a single cell.
    footer_text+="%F{${seg_colors[i]}}${seg_texts[i]//\%/%%}%f"
    footer_text_raw+=${seg_texts[i]}
  done
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
  local status_color='70'         # green
  (( last_status != 0 )) && status_color='#B90000'  # RGB(185,0,0)

  # cwd with ~ collapse, expanded via prompt-escape so we get the real
  # string for both display and width math (no double-expansion later).
  local cwd=${(%):-%~}
  # Timestamp at footer-print time (when the command finished, not started).
  local timestamp=${(%):-%D{%-I:%M:%S %p}}

  # Branch when on one, short commit when detached, empty outside a repo.
  # [LAW:no-silent-failure] exception: git's stderr here is only "not a git
  # repository" — a domain absence, not a failure; it becomes an absent segment.
  local branch
  branch=$(command git symbolic-ref --short -q HEAD 2>/dev/null) ||
    branch=$(command git rev-parse --short HEAD 2>/dev/null)
  # Long refs display first-12…last-12, same rule as the prompt's branch
  # segment (30-git-formatter.zsh). Applied before the segment list so the
  # width math sees the truncated value; empty stays empty.
  branch=$(_rad_p10k_shorten_ref "$branch")

  # Per-field colors — muted to match the timestamp's teal saturation.
  #   timestamp = 66  (TIME_FOREGROUND, muted teal)
  #   duration  = 100 (dim olive-yellow)
  #   cwd       = 31  (DIR_FOREGROUND, blue)
  #   branch    = 96  (muted purple; absent outside a git repo)
  #   cmd_name  = 65  (sage green — dimmer than VCS-clean's 76)
  # Separator dot stays dim (240) so it recedes visually.
  #
  # [LAW:dataflow-not-control-flow] an empty text is an absent segment — the
  # branch's optionality lives in the value, not in splicing logic.
  local -a seg_colors=( 66           100            31     96        65          )
  local -a seg_texts=( "$timestamp" "$elapsed_str" "$cwd" "$branch" "$cmd_name" )
  local -i cwd_i=3  # cwd's slot in the lists — the one segment the fit resizes

  # Layout: ╰─ + footer_text + ' ❯' + N×─    (gray ❯ butts up to the dashes)
  # The ❯ is the same gray (244) as the live PROMPT_CHAR — visual rhyme
  # between the footer and the live prompt below.
  local -i prefix_cells=2  # "╰─"
  local -i sep_cells=2     # " ❯"

  # Measure with the full cwd, then fit the cwd — the one unbounded segment —
  # to the overflow and assemble again. When everything already fits, the fit
  # is the identity and the second assembly reproduces the first byte-for-byte.
  local footer_text footer_text_raw
  _rad_p10k_footer_assemble
  local -i overflow=$(( $#footer_text_raw + prefix_cells + sep_cells - COLUMNS ))
  seg_texts[cwd_i]=$(_rad_p10k_fit_cwd "${seg_texts[cwd_i]}" $(( $#seg_texts[cwd_i] - overflow )))
  _rad_p10k_footer_assemble

  local -i dash_count=$(( COLUMNS - prefix_cells - $#footer_text_raw - sep_cells ))
  (( dash_count < 0 )) && dash_count=0
  local _empty=
  local dashes=${(l:dash_count::─:)_empty}

  print -P -- "%F{244}╰─%f${footer_text} %F{$status_color}❯%f%F{$status_color}${dashes}%f"
}

# Prepend ╭─ to p10k's transient prompt. p10k builds _p9k_transient_prompt
# during its init, which runs after all plugins are sourced — so on first load
# the variable doesn't exist yet. Use a one-shot precmd hook to inject once
# p10k is guaranteed initialized. On re-source, 90-finalize.zsh injects
# immediately after `p10k reload` — this hook then fires once and is a no-op
# (the pattern already matched).
function _rad_p10k_inject_transient_prefix() {
  add-zsh-hook -d precmd _rad_p10k_inject_transient_prefix
  (( $+_p9k_transient_prompt )) || return 0
  _p9k_transient_prompt=${_p9k_transient_prompt/'%b%k%s%u%(?'/'%b%k%s%u%F{244}╭─%(?'}
}

add-zsh-hook preexec _rad_p10k_footer_preexec
add-zsh-hook precmd  _rad_p10k_footer_precmd
add-zsh-hook precmd  _rad_p10k_inject_transient_prefix
