#!/usr/bin/env zsh
# Smoke tests for claad (claude-code.plugin.zsh): claude replaces the shell
# with SHELL=bash and the argv intact, and a claude that cannot be exec'd is
# reported to a shell that is still alive.
#
# Re-execs under `zsh -f` so the user's shell config can't leak in. Every case
# runs against a throwaway PATH under a temp dir; nothing touches the user's
# environment. claad is always called inside ( ) here: exec replaces that
# subshell, not the test.
#
# Run: claude-code/tests/run_claad_tests.zsh

[[ -n ${RAD_CLAAD_TEST_REEXEC:-} ]] || exec env RAD_CLAAD_TEST_REEXEC=1 zsh -f "${(%):-%x}"

typeset -g script_dir=${${(%):-%x}:A:h}
source "${script_dir:h}/claude-code.plugin.zsh"

source "${script_dir:h:h}/tests/harness.zsh"

typeset -g tmp=$(mktemp -d) && trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
# The stand-in claude reports what it was exec'd with: SHELL, and each argv
# word in its own brackets so a lost word boundary shows.
cat > "$tmp/bin/claude" <<'FAKE'
#!/bin/sh
printf 'SHELL=%s argv=' "$SHELL"; printf '[%s]' "$@"; printf '\n'
FAKE
chmod +x "$tmp/bin/claude"

# ---- exec arm ----------------------------------------------------------------

# claad replaces the shell: the line after it never runs.
typeset -g out
out=$( PATH=$tmp/bin:/usr/bin:/bin; claad --resume x "a b"; print NOT-REACHED )
ok "exec: claude replaces the shell, with SHELL=bash and argv intact" \
   "SHELL=bash argv=[--dangerously-skip-permissions][--resume][x][a b]" "$out"

out=$( PATH=$tmp/bin:/usr/bin:/bin; alias claude='/nonexistent/claude'; claad; print NOT-REACHED )
ok "exec: an alias named claude is bypassed for the PATH binary" \
   "SHELL=bash argv=[--dangerously-skip-permissions]" "$out"

out=$( PATH=$tmp/bin:/usr/bin:/bin; claude() { print WRAPPER; }; claad; print NOT-REACHED )
ok "exec: a function named claude is bypassed for the PATH binary" \
   "SHELL=bash argv=[--dangerously-skip-permissions]" "$out"

# ---- failure arm: the shell survives ----------------------------------------

out=$( PATH=/usr/bin:/bin; claad 2>&1; print "rc=$? survived" )
ok "missing: claad returns 127, reports, and the shell is still there" \
   "claad: no executable 'claude' on PATH
rc=127 survived" "$out"

mkdir -p "$tmp/noexec" && : > "$tmp/noexec/claude"
out=$( PATH=$tmp/noexec:/usr/bin:/bin; claad 2>&1; print "rc=$? survived" )
ok "not executable: same report, shell still there" \
   "claad: no executable 'claude' on PATH
rc=127 survived" "$out"

# ---- summary ---------------------------------------------------------------

summary
