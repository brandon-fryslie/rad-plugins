# JetBrains IDE helpers

# Launch IntelliJ IDEA with a JDWP debug agent on a free random port.
# Finds the latest installed IntelliJ config dir, copies the user's base
# idea.vmoptions, appends a JDWP agent line bound to a kernel-assigned free
# port, and launches idea pointed at the resulting temp vmoptions file.
idea-debug() {
  local -a config_dirs=( "$HOME/Library/Application Support/JetBrains/IntelliJIdea"*/(N) )
  local config_dir="${config_dirs[-1]}"
  [[ -d "$config_dir" ]] || { echo "idea-debug: no IntelliJ IDEA config dir under ~/Library/Application Support/JetBrains/" >&2; return 1; }

  local port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')
  [[ "$port" =~ ^[0-9]+$ ]] || { echo "idea-debug: failed to pick a free port" >&2; return 1; }

  local base="${config_dir}idea.vmoptions"
  local vmopts=$(mktemp -t idea-debug)
  # Base vmoptions may lack a trailing newline; unconditional `print` separator
  # guarantees the JDWP line lands on its own line.
  {
    [[ -f "$base" ]] && cat "$base"
    print
    print -- "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:${port}"
  } > "$vmopts"

  echo "idea-debug: JDWP listening on ${port}"
  echo "idea-debug: vmoptions -> ${vmopts}"
  IDEA_VM_OPTIONS="$vmopts" idea "$@"
}
