#!/usr/bin/env zsh
# Smoke tests for the rad-p10k command footer (config/50-transient.zsh) and
# the shared ref-truncation helper (config/30-git-formatter.zsh).
#
# Re-execs under `zsh -f` so the user's shell config can't leak in. Everything
# runs against throwaway git repos under a temp HOME; nothing touches the
# user's environment.
#
# Run: rad-p10k/tests/run_footer_tests.zsh

# LC_ALL pinned to a UTF-8 locale: ${(m)#} falls back to byte counting under
# C/POSIX, which would silently change every width assertion below.
[[ -n ${RAD_FOOTER_TEST_REEXEC:-} ]] || exec env RAD_FOOTER_TEST_REEXEC=1 LC_ALL=en_US.UTF-8 zsh -f "${(%):-%x}"

zmodload zsh/datetime

# Loud precondition, not a graceful skip: if the pinned locale is unavailable,
# ${(m)#} byte-counts and every width assertion becomes a red herring — probe
# the exact property the suite depends on and fail with the real cause.
typeset _wide=日
if (( ${(m)#_wide} != 2 )); then
  print -ru2 -- "FATAL: no usable UTF-8 locale (\${(m)#} is not counting display cells);"
  print -ru2 -- "       the width assertions below require en_US.UTF-8 to be installed."
  exit 1
fi
unset _wide

typeset -g script_dir=${${(%):-%x}:A:h}
source "${script_dir:h}/config/30-git-formatter.zsh"
source "${script_dir:h}/config/50-transient.zsh"

typeset -gi PASS=0 FAIL=0

# ok <desc> <expected> <actual> — exact-match assertion
function ok() {
  if [[ $2 == $3 ]]; then
    (( ++PASS )); print -r -- "ok   - $1"
  else
    (( ++FAIL )); print -r -- "FAIL - $1"
    print -r -- "       expected: ${(qqqq)2}"
    print -r -- "       actual:   ${(qqqq)3}"
  fi
}

# okm <desc> <glob-pattern> <actual> — pattern assertion (use ^pat to negate)
function okm() {
  local negate= pat=$2
  [[ $pat == '^'* ]] && { negate=1; pat=${pat#^}; }
  if [[ -z $negate && $3 == ${~pat} || -n $negate && $3 != ${~pat} ]]; then
    (( ++PASS )); print -r -- "ok   - $1"
  else
    (( ++FAIL )); print -r -- "FAIL - $1"
    print -r -- "       pattern:  ${(qqqq)2}"
    print -r -- "       actual:   ${(qqqq)3}"
  fi
}

# Renders one footer line in <dir> at width <columns>; REPLY = the line with
# ANSI escapes stripped, so ${(m)#REPLY} is its display width in cells.
function run_footer() {
  # extendedglob only here, for the ANSI-strip's # repetition glob — globally
  # it would turn ~ in the assertion patterns into the exclusion operator.
  setopt localoptions extendedglob
  local -i columns=$1
  local dir=$2
  local out
  out=$(
    cd "$dir" || exit 1
    COLUMNS=$columns
    typeset -gF _RAD_P10K_CMD_START=$(( EPOCHREALTIME - 0.2341 ))
    typeset -g _RAD_P10K_CMD_NAME=gitstatusquery
    _rad_p10k_footer_precmd
  ) || { print -r -- "FATAL: footer render failed in $dir" >&2; exit 1; }
  REPLY=${out//$'\e'\[[0-9;]#m/}
}

# Separator count in a rendered line — segments present is seps + 1.
function sep_count() {
  local stripped=${1// • /}
  print -r -- $(( ($#1 - $#stripped) / 3 ))
}

# ---- sandbox ---------------------------------------------------------------

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
export HOME=$work                 # %~ collapses test paths to ~/...
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

long_branch='feature/abcdefghijklmnopqrstuvwxyz-01234'   # 40 chars
trunc_branch="${long_branch[1,12]}…${long_branch[-12,-1]}"

repo=$work/repo
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$repo" checkout -q -b "$long_branch"

# ---- _rad_p10k_shorten_ref units -------------------------------------------

ref32=${(l:32::a:)}
ref33=${(l:33::b:)}
ok "shorten_ref: 32-char ref untouched" "$ref32" "$(_rad_p10k_shorten_ref "$ref32")"
ok "shorten_ref: 33-char ref -> first-12…last-12" \
  "${ref33[1,12]}…${ref33[-12,-1]}" "$(_rad_p10k_shorten_ref "$ref33")"
ok "shorten_ref: empty -> empty" "" "$(_rad_p10k_shorten_ref "")"

# ---- _rad_p10k_fit_cwd units -----------------------------------------------

ok "fit_cwd: fitting cwd passes through unchanged" \
  "~/code/rad-plugins" "$(_rad_p10k_fit_cwd "~/code/rad-plugins" 40)"
ok "fit_cwd: leading components collapse to first char, last kept whole" \
  "/u/l/s/d/nested/dir" "$(_rad_p10k_fit_cwd "/usr/local/share/deep/nested/dir" 20)"
ok "fit_cwd: fully collapsed but still long -> …tail within budget" \
  "…d/n/dir" "$(_rad_p10k_fit_cwd "/usr/local/share/deep/nested/dir" 8)"
ok "fit_cwd: floor at bare ellipsis" "…" "$(_rad_p10k_fit_cwd "~/anything" 1)"

# Wide characters: budgets are display cells, and CJK/emoji occupy two cells
# per character — char-counting math would pass these strings through untouched.
ok "fit_cwd: CJK cwd within budget passes through" \
  "~/日本語/プロジェクト" "$(_rad_p10k_fit_cwd "~/日本語/プロジェクト" 40)"
ok "fit_cwd: CJK components collapse by cell width" \
  "~/日/深い/プロジェクト" "$(_rad_p10k_fit_cwd "~/日本語/深い/プロジェクト" 22)"
ok "fit_cwd: CJK …tail trimmed to cells, not chars" \
  "…クトリ" "$(_rad_p10k_fit_cwd "/長い/パス/ディレクトリ" 8)"
ok "fit_cwd: unsplittable 2-cell char lands one under budget" \
  "…示" "$(_rad_p10k_fit_cwd "/日本語表示" 4)"
ok "fit_cwd: emoji counts 2 cells" \
  "…arty" "$(_rad_p10k_fit_cwd "~/🎉party" 5)"

# ---- footer in a repo with a long branch -----------------------------------

run_footer 120 "$repo"
ok  "repo: footer is exactly COLUMNS cells" 120 ${(m)#REPLY}
okm "repo: truncated branch present" "*${trunc_branch}*" "$REPLY"
okm "repo: full branch name absent" "^*${long_branch}*" "$REPLY"
ok  "repo: five segments present" 4 "$(sep_count "$REPLY")"

# ---- detached HEAD ---------------------------------------------------------

git -C "$repo" checkout -q --detach
sha=$(git -C "$repo" rev-parse --short HEAD)
run_footer 120 "$repo"
okm "detached: short sha shown" "* • ${sha} • *" "$REPLY"
ok  "detached: footer is exactly COLUMNS cells" 120 ${(m)#REPLY}
git -C "$repo" checkout -q "$long_branch"

# ---- outside a repo --------------------------------------------------------

plain=$work/plain
mkdir -p "$plain"
run_footer 120 "$plain"
ok "non-repo: four segments (no branch)" 3 "$(sep_count "$REPLY")"
ok "non-repo: footer is exactly COLUMNS cells" 120 ${(m)#REPLY}

# ---- overflow: deep cwd at narrow COLUMNS ----------------------------------

# Tight budget (~8 cells for the cwd): the fit falls through component
# collapse to the …tail form, but every segment stays on the line and the
# line stays exactly terminal-width.
deep=$work/really/deep/nested/path/with/many/long-components/overflowing-directory
mkdir -p "$deep"
git -C "$deep" init -q -b "$long_branch"
git -C "$deep" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

run_footer 80 "$deep"
ok  "overflow tight: footer is exactly COLUMNS cells" 80 ${(m)#REPLY}
ok  "overflow tight: all five segments still present" 4 "$(sep_count "$REPLY")"
okm "overflow tight: branch survives the fit" "*${trunc_branch}*" "$REPLY"
okm "overflow tight: command name survives the fit" "* gitstatusquery *" "$REPLY"
okm "overflow tight: cwd kept as ellipsis tail" "* • …* • ${trunc_branch} *" "$REPLY"

# Moderate budget (~32 cells for a 42-cell cwd): component collapse alone
# absorbs the overflow, so the last component survives whole.
mid=$work/really/deep/nested/overflowing-directory
mkdir -p "$mid"
git -C "$mid" init -q -b "$long_branch"
git -C "$mid" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

run_footer 105 "$mid"
ok  "overflow moderate: footer is exactly COLUMNS cells" 105 ${(m)#REPLY}
okm "overflow moderate: cwd collapsed to first-char components" \
  "*~/r/d/n/overflowing-directory*" "$REPLY"

run_footer 300 "$deep"
okm "generous width: full cwd verbatim" \
  "* ~/really/deep/nested/path/with/many/long-components/overflowing-directory *" "$REPLY"
ok  "generous width: footer is exactly COLUMNS cells" 300 ${(m)#REPLY}

# ---- CJK cwd: footer width math counts cells, not characters ---------------

# "~/日本語/深いディレクトリ" is 13 characters but 25 cells; char-based math
# under-measures by 12 and pads 12 dashes too many, wrapping the line.
cjk=$work/日本語/深いディレクトリ
mkdir -p "$cjk"
git -C "$cjk" init -q -b "$long_branch"
git -C "$cjk" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init

run_footer 200 "$cjk"
okm "cjk generous: full cwd verbatim" "* ~/日本語/深いディレクトリ *" "$REPLY"
ok  "cjk generous: footer is exactly COLUMNS cells" 200 ${(m)#REPLY}

run_footer 80 "$cjk"
ok  "cjk tight: footer is exactly COLUMNS cells" 80 ${(m)#REPLY}
ok  "cjk tight: all five segments still present" 4 "$(sep_count "$REPLY")"
okm "cjk tight: branch survives the fit" "*${trunc_branch}*" "$REPLY"

# ---- my_git_formatter routes through the shared helper ---------------------

P9K_CONTENT= VCS_STATUS_LOCAL_BRANCH=$long_branch VCS_STATUS_TAG= \
  VCS_STATUS_REMOTE_BRANCH= VCS_STATUS_COMMIT=0123456789ab my_git_formatter 1
okm "prompt segment: branch truncated via shared helper" "*${trunc_branch}*" "$my_git_format"

# ---- summary ---------------------------------------------------------------

print -r -- "----"
print -r -- "pass: $PASS  fail: $FAIL"
(( FAIL == 0 )) || exit 1
