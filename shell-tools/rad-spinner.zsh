###############################################################################
# build_frames – full‑dot psychedelic mosaic (zsh, 1‑based arrays)           #
# Produces global frames[] each padded exactly 7 columns                     #
###############################################################################
build_frames() {
  typeset -ga frames
  frames=()

  # Define an array of Braille glyphs
  local -a braille_glyphs=(
    $'\u2800' $'\u2801' $'\u2802' $'\u2803' $'\u2804'
    $'\u2805' $'\u2806' $'\u2807' $'\u2808' $'\u2809'
    $'\u280A' $'\u280B' $'\u280C' $'\u280D' $'\u280E'
    $'\u280F' $'\u2810' $'\u2811' $'\u2812' $'\u2813'
    # Add more glyphs as needed
  )
  local cells=5             # Number of Braille glyphs per frame
  local scroll=20           # time steps before ping‑pong reverse

  # Lookup arrays for individual dot bitmasks (1‑based rows)
  local -a maskL=('' 1 2 4 8)            # dots 1‑4 (left column)
  local -a maskR=('' 16 32 64 128)       # dots 5‑8 (right column)

  for ((t=0; t<scroll; t++)); do
    local frame=""
    for ((c=0; c<cells; c++)); do
      # Use a simple pattern or index to select glyphs
      local index=$(( (t + c) % ${#braille_glyphs[@]} ))
      frame+="${braille_glyphs[index]}"
    done
    frames+=( "$(printf '%-7s' "$frame")" )
  done

  # Ping‑pong reverse for smooth back‑and‑forth motion
  for ((idx=${#frames}-1; idx>1; idx--)); do
    frames+=( "${frames[idx]}" )
  done

  frames+=( '       ' )        # trailing blank frame to dissolve
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
  zsh -l <<EOF
  source /Users/bmf/.zgen/brandon-fryslie/rad-plugins-master/shell-tools/rad-spinner.zsh

  rad_spinner_start "Starting up..."
  sleep 1
  rad_spinner_update "Step 1/3 — Connecting…"
  sleep 1.5
  rad_spinner_update "Step 2/3 — Processing…"
  sleep 2
  rad_spinner_update "Step 3/3 — Finalizing…"
  sleep 1
  rad_spinner_stop
EOF
}

###############################################################################
# End of updated loader                                                      #
###############################################################################
