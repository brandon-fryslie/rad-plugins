#!/usr/bin/env zsh
# Tests for the remote-control server proj2z brings up alongside each project
# tmux session.
#
# Hermetic: runs against a private tmux server in a temp TMUX_TMPDIR with a
# stand-in `claude` on PATH, so it never touches the real tmux server, the
# network, or the user's Claude account. The server is started with a config of
# this suite's own, pinning `default-shell` to /bin/sh - tmux hands every pane to
# a shell, and the developer's shell would source their dotfiles and rebuild PATH
# out from under the stand-in. What each window is *told* to run is asserted
# through #{pane_start_command} rather than by intercepting the binary.

set -uo pipefail

SCRIPT_DIR="${${(%):-%x}:A:h}"
PROJ2_SRC="${SCRIPT_DIR}/../../proj2.zsh"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

WORK="$(mktemp -d)"
export PROJ2Z_RC_SESSION="p2z-test-$$"
unset TMUX
export TMUX_TMPDIR="$WORK/tmux"
mkdir -p "$TMUX_TMPDIR"

passed=0
failed=0

check() {  # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    print -r -- "${GREEN}✓ PASS${NC}  $1"
    passed=$((passed + 1))
  else
    print -r -- "${RED}✗ FAIL${NC}  $1"
    print -r -- "        expected: $2"
    print -r -- "        actual:   $3"
    failed=$((failed + 1))
  fi
}

contains() {  # contains <description> <needle> <haystack>
  if [[ "$3" == *"$2"* ]]; then
    print -r -- "${GREEN}✓ PASS${NC}  $1"
    passed=$((passed + 1))
  else
    print -r -- "${RED}✗ FAIL${NC}  $1"
    print -r -- "        needle:   $2"
    print -r -- "        haystack: $3"
    failed=$((failed + 1))
  fi
}

cleanup() {
  tmux kill-server 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

if ! command -v tmux &> /dev/null; then
  print -r -- "${YELLOW}⚠ tmux not installed - skipping remote-control tests${NC}"
  exit 0
fi

# The stand-in records the argv it was handed and then idles like a real server.
# It writes into its own cwd, which makes the record per-project for free: tmux
# starts each pane in the project directory.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/claude" <<'STANDIN'
#!/bin/sh
printf '%s\n' "$@" > "$(pwd)/.claude-argv"
sleep 300
STANDIN
chmod +x "$WORK/bin/claude"
export PATH="$WORK/bin:$PATH"

# Start the private server here, before anything else reaches for tmux, so every
# window it ever opens inherits a shell that reads no dotfiles and leaves the
# exported PATH above intact. Passing -f also keeps ~/.tmux.conf out of the run.
printf 'set -g default-shell /bin/sh\n' > "$WORK/tmux.conf"
tmux -f "$WORK/tmux.conf" new-session -d -s "p2z-boot-$$" -c "$WORK" 'sleep 3000' || {
  print -r -- "${RED}✗ could not start the private tmux server${NC}"
  exit 1
}

rc_windows() {
  tmux list-windows -t "=${PROJ2Z_RC_SESSION}" -F '#{window_name}' 2>/dev/null | sort | tr '\n' ','
}

# Build an rc_windows expectation from window names, so the maintenance window is
# named once - by proj2.zsh - and this suite never spells it out a second time.
rc_expect() {  # rc_expect <window name>...
  print -rl -- "$@" | sort | tr '\n' ','
}

# What the stand-in was actually handed. The pane starts asynchronously, so wait
# for the record rather than assuming it is already there.
argv_of() {  # argv_of <project dir>
  local log="$1/.claude-argv"
  for _ in {1..50}; do
    [[ -s "$log" ]] && break
    sleep 0.1
  done
  tr '\n' '|' < "$log"
}

# Panes carrying the identity stamp, read through the name proj2.zsh gives it.
rc_stamps() {  # rc_stamps [<extra list-panes args>...]
  tmux list-panes -s -t "=${PROJ2Z_RC_SESSION}" -F "#{${_PROJ2Z_RC_STAMP}}" "$@"
}

# A project name containing a space, since proj2z permits those.
PROJECT="$WORK/projects/my project"
mkdir -p "$PROJECT"

source "$PROJ2_SRC"

print -r -- ""
print -r -- "${YELLOW}TEST 1: brings up a detached server in the shared session${NC}"

out=$(_proj2z_ensure_remote_control "$PROJECT")
check "names where the server landed" \
  "Remote control: ${PROJ2Z_RC_SESSION}:my project (p2rc to inspect)" "$out"

check "holds a maintenance shell alongside the project window" \
  "$(rc_expect 'my project' "$_PROJ2Z_RC_HOME_WINDOW")" "$(rc_windows)"

attached=$(tmux list-sessions -F '#{session_attached}' \
  -f "#{==:#{session_name},${PROJ2Z_RC_SESSION}}")
check "the session is backgrounded, not attached" "0" "$attached"

pane=$(tmux list-windows -t "=${PROJ2Z_RC_SESSION}" \
  -F '#{pane_dead}|#{pane_current_path}' -f '#{==:#{window_name},my project}')
check "the window is alive and in the project directory" "0|${PROJECT:A}" "$pane"

check "hands the server the worktree spawn config, project name as one argument" \
  "remote-control|--spawn|worktree|--name|my project|" "$(argv_of "$PROJECT")"

remain=$(tmux show-options -p -v -t "=${PROJ2Z_RC_SESSION}:=my project" remain-on-exit)
check "the pane outlives a dying server so its error stays readable" "on" "$remain"

print -r -- ""
print -r -- "${YELLOW}TEST 2: converges - a running server is left alone, silently${NC}"

out=$(_proj2z_ensure_remote_control "$PROJECT")
check "says nothing when the server is already up" "" "$out"
check "no duplicate window" "1" \
  "$(tmux list-windows -t "=${PROJ2Z_RC_SESSION}" -F '#{window_name}' | grep -c '^my project$')"

print -r -- ""
print -r -- "${YELLOW}TEST 3: converges - a dead server is revived${NC}"

# remain-on-exit keeps the window after the server exits, so a crashed server is
# a live window with a dead pane - the shape a name-only check would misread.
tmux send-keys -t "=${PROJ2Z_RC_SESSION}:=my project" C-c
for _ in {1..50}; do
  [[ "$(tmux list-windows -t "=${PROJ2Z_RC_SESSION}" -F '#{pane_dead}' \
        -f '#{==:#{window_name},my project}')" == 1 ]] && break
  sleep 0.1
done
check "the crashed server left a dead window behind" "1" \
  "$(tmux list-windows -t "=${PROJ2Z_RC_SESSION}" -F '#{pane_dead}' \
     -f '#{==:#{window_name},my project}')"

out=$(_proj2z_ensure_remote_control "$PROJECT")
check "reports bringing the server back" \
  "Remote control: ${PROJ2Z_RC_SESSION}:my project (p2rc to inspect)" "$out"
check "the revived window is alive" "0" \
  "$(tmux list-windows -t "=${PROJ2Z_RC_SESSION}" -F '#{pane_dead}' \
     -f '#{==:#{window_name},my project}')"
check "revival replaced the window rather than adding one" \
  "$(rc_expect 'my project' "$_PROJ2Z_RC_HOME_WINDOW")" "$(rc_windows)"

print -r -- ""
print -r -- "${YELLOW}TEST 4: a second project gets its own window in the same session${NC}"

mkdir -p "$WORK/projects/other"
_proj2z_ensure_remote_control "$WORK/projects/other" > /dev/null
check "both projects hosted side by side" \
  "$(rc_expect 'my project' other "$_PROJ2Z_RC_HOME_WINDOW")" "$(rc_windows)"

print -r -- ""
print -r -- "${YELLOW}TEST 5: identity is the project path, not the window name${NC}"

# The collision a name-keyed lookup got wrong: one basename, two projects.
mkdir -p "$WORK/a/twin" "$WORK/b/twin"
_proj2z_ensure_remote_control "$WORK/a/twin" > /dev/null
twin_out=$(_proj2z_ensure_remote_control "$WORK/b/twin")
contains "the second twin still brings up its own server" \
  "Remote control: ${PROJ2Z_RC_SESSION}:twin" "$twin_out"
check "each twin holds a window" "2" \
  "$(tmux list-windows -t "=${PROJ2Z_RC_SESSION}" -F '#{window_name}' | grep -c '^twin$')"
check "each pane carries the project it serves" "$WORK/a/twin,$WORK/b/twin," \
  "$(rc_stamps -f '#{==:#{window_name},twin}' | sort | tr '\n' ',')"
check "both twins are running" "0,0," \
  "$(tmux list-panes -s -t "=${PROJ2Z_RC_SESSION}" -F '#{pane_dead}' \
     -f '#{==:#{window_name},twin}' | tr '\n' ',')"

# The maintenance window is named `shell` and carries no stamp, so a project of
# the same name matches nothing and is served on its own terms.
mkdir -p "$WORK/projects/shell"
shell_out=$(_proj2z_ensure_remote_control "$WORK/projects/shell")
contains "a project named after the maintenance window gets a server" \
  "Remote control: ${PROJ2Z_RC_SESSION}:shell" "$shell_out"
check "the maintenance window was left where it was" "2" \
  "$(tmux list-windows -t "=${PROJ2Z_RC_SESSION}" -F '#{window_name}' | grep -c '^shell$')"

print -r -- ""
print -r -- "${YELLOW}TEST 6: a missing claude warns without failing navigation${NC}"

# Empty by construction: the missing-claude branch returns before any tmux call,
# so borrowing tmux's bin directory only risked finding a real `claude` beside it.
mkdir -p "$WORK/empty"
missing_out=$(PATH="$WORK/empty" \
  _proj2z_ensure_remote_control "$WORK/projects/other" 2>&1)
check "does not fail - p2z still navigates" "0" "$?"
contains "names the cause" "claude is not installed" "$missing_out"

print -r -- ""
print -r -- "${YELLOW}TEST 7: p2rc fails loudly with no session${NC}"

absent_out=$(PROJ2Z_RC_SESSION="p2z-absent-$$" proj2z_remote_control 2>&1)
check "fails nonzero" "1" "$?"
contains "says how to start one" "p2z into a project" "$absent_out"

print -r -- ""
print -r -- "${YELLOW}TEST 8: a human's own pane never answers for the server${NC}"

# p2rc invites the user into this session, so they may split a project window.
# Liveness has to follow the stamped server pane, not whichever pane is active -
# reading the window instead reports a crashed server as running, forever.
OTHER="$WORK/projects/other"
split_pane=$(tmux split-window -d -P -F '#{pane_id}' \
  -t "=${PROJ2Z_RC_SESSION}:=other" -c "$WORK" 'sleep 300')
tmux select-pane -t "$split_pane"
server_pane=$(tmux list-panes -s -t "=${PROJ2Z_RC_SESSION}" -F '#{pane_id}' \
  -f "#{==:#{${_PROJ2Z_RC_STAMP}},${OTHER}}")
tmux send-keys -t "$server_pane" C-c
for _ in {1..50}; do
  [[ "$(tmux display-message -p -t "$server_pane" '#{pane_dead}')" == 1 ]] && break
  sleep 0.1
done
check "the server died while the user's pane stayed active" "1|1" \
  "$(tmux display-message -p -t "$server_pane" '#{pane_dead}')|$(tmux display-message -p -t "$split_pane" '#{pane_active}')"
revive_out=$(_proj2z_ensure_remote_control "$OTHER")
contains "the crash is still seen, and the server revived" \
  "Remote control: ${PROJ2Z_RC_SESSION}:other" "$revive_out"
check "the revived server pane is running" "0" \
  "$(tmux display-message -p -t "$server_pane" '#{pane_dead}')"
check "the user's own pane was left alone" "0" \
  "$(tmux display-message -p -t "$split_pane" '#{pane_dead}')"

print -r -- ""
print -r -- "${YELLOW}TEST 9: the remote-control session sits outside the project namespace${NC}"

# What keeps a project called `remote-control` from being redirected into the
# shared session, or having a server injected into its own: no name a project may
# legally carry can equal the session's name.
default_rc=$(PROJ2Z_RC_SESSION= _proj2z_rc_session_name)
_proj2z_validate_project_name "$default_rc" 2>/dev/null
check "no legal project name can equal the default RC session" "1" "$?"

print -r -- ""
print -r -- "========================================="
print -r -- "Remote Control Test Results"
print -r -- "========================================="
print -r -- "Total:  $((passed + failed))"
print -r -- "${GREEN}Passed: ${passed}${NC}"
print -r -- "${RED}Failed: ${failed}${NC}"
print -r -- "========================================="

(( failed == 0 ))
