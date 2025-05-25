###############################################################################
# Zsh Options and Environment Setup                                           #
###############################################################################
setopt KSH_ARRAYS        # Use 0-based indexing
setopt EXTENDED_GLOB     # Enable extended globbing
setopt NULL_GLOB         # Patterns that don't match files expand to nothing
setopt ERR_EXIT          # Exit immediately if a command fails
# set -x                   # Print each command before executing (debugging)
# set -v                   # Print shell input lines as they are read (verbose)
# trap 'echo "Error at line $LINENO"' ERR  # Trace errors

export SHELL=/bin/zsh    # Ensure SHELL is set to Zsh
export ZDOTDIR=$HOME     # Set ZDOTDIR to home if using custom config directory
export PATH=$PATH:$HOME/bin  # Ensure custom scripts are in PATH

###############################################################################
build_frames() {
  typeset -ga frames
  frames=()

  # Define a 2D array of Braille glyphs
  local -a braille_grid
  local rows=16
  local cols=16

  # Initialize the array with the correct size
  braille_grid=()

  # Populate the 2D array with all 256 Braille glyphs
  for ((i=0; i<rows; i++)); do
    for ((j=0; j<cols; j++)); do
      local index=$((i * cols + j))
      if (( index >= 0 && index < rows * cols )); then
        braille_grid[index]=$'\u28'$(printf "%02X" "$index")
      fi
    done
  done

  local cells=5             # Number of Braille glyphs per frame
  local scroll=20           # Number of frames before reversing


  for ((t=0; t<scroll; t++)); do
    local frame=""
    for ((c=0; c<cells; c++)); do
      # Calculate row and column indices
      local row=$(( (t + c) % rows ))
      local col=$(( (t + c) % cols ))
      local grid_index=$((row * cols + col))
      if (( grid_index >= 0 && grid_index < rows * cols )); then
        frame+="${braille_grid[grid_index]}"
      fi
    done
    frames+=( "$(printf '%-7s' "$frame")" )
  done

  # Ping-pong reverse for smooth back-and-forth motion
  for ((idx=${#frames}-1; idx>1; idx--)); do
    frames+=( "${frames[idx]}" )
  done

  frames+=( '       ' )        # Trailing blank frame to dissolve
}
###############################################################################
# Quiet Rainbow Loader (no rm prompts, no [n] job messages, no flicker)       #
###############################################################################
###############################################################################
# Quiet Rainbow Loader – multi‑column Braille “pixel” animation               #
###############################################################################
###############################################################################
# Quiet Rainbow Loader – zsh‑native (1‑based arrays)                          #
###############################################################################
rad_spinner_start() {
  set +m                               # suppress job control messages

  LOADER_FIFO=$(mktemp -u) && mkfifo "$LOADER_FIFO"
  exec 3<>"$LOADER_FIFO"
  command rm -f "$LOADER_FIFO"
  LOADER_MSG="$*"

  tput civis
  trap rad_spinner_stop INT

  ###########################################################################
  # 1. Build frames (10×4 pixel field rendered by 5 Braille cells)          #
  ###########################################################################
  build_frames

  ###########################################################################
  # 2. Animation loop                                                       #
  ###########################################################################
  local -a colors=(31 33 32 36 34 35)
  local i=1       # 1‑based for frames
  local c=1       # 1‑based for colors
  local msg="$LOADER_MSG"

  {
    while true; do
      # non‑blocking message update
      if read -r -t 0.05 newmsg <&3; then
        msg="$newmsg"
      fi

      printf "\r\033[0K\033[%sm%-7s \033[1m%s\033[0m" \
             "${colors[c]}" "${frames[i]}" "$msg"

      (( i = i % ${#frames} + 1 ))
      (( c = c % ${#colors} + 1 ))
      sleep 0.1
    done
  } &!     # background without job‑control output
  LOADER_PID=$!
}

rad_spinner_update() {
  kill -0 "${LOADER_PID:-0}" 2>/dev/null && printf "%s\n" "$*" >&3
}

rad_spinner_stop() {
  kill -0 "${LOADER_PID:-0}" 2>/dev/null && {
    kill "$LOADER_PID"
    wait "$LOADER_PID" 2>/dev/null
  }
  exec 3>&-
  tput cnorm
  printf "\r\033[32m✔ Done.\033[0m\n"
  trap - INT
}

rad_spinner_test() {
#  zsh -l <<EOF
#  source /Users/bmf/.zgen/brandon-fryslie/rad-plugins-master/shell-tools/rad-spinner.zsh

  rad_spinner_start "Starting up..."
  sleep 1
  rad_spinner_update "Step 1/3 — Connecting…"
  sleep 1.5
  rad_spinner_update "Step 2/3 — Processing…"
  sleep 2
  rad_spinner_update "Step 3/3 — Finalizing…"
  sleep 1
  rad_spinner_stop
#EOF
}

###############################################################################
# End of updated loader                                                      #
###############################################################################
