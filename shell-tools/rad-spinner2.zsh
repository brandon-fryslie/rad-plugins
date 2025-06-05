###############################################################################
# Psychedelic Fractal Loader for Bash / zsh                                   #
#   rad_spinner2_start "message"                                              #
#   rad_spinner2_update "new message"                                         #
#   rad_spinner2_stop                                                         #
###############################################################################

rad_spinner2_start() {
  FL_FIFO=$(mktemp -u) && mkfifo "$FL_FIFO"
  exec 3<>"$FL_FIFO"        # fd 3 = control pipe
  rm "$FL_FIFO"

  FL_MSG="$*"
  FL_PID=
  tput civis                # hide cursor
  trap rad_spinner2_stop INT

  {
    local width=$(($(tput cols)-1))
    local row=0 rowDir=1         # controls fractal “depth” (fade)
    local offset=0 offDir=1      # controls left/right glide
    local colorShift=0
    local maxDepth=7             # visual fade length

    while :; do
      # Allow non‑blocking message update
      if read -r -t 0.01 newmsg <&3; then
        FL_MSG="$newmsg"
      fi

      # Build fractal line
      local line=""
      for ((x=0; x<width; x++)); do
        # Sierpiński test: char on when (x+row) & row == 0
        if (( ((x + row) & row) == 0 )); then
          # psychedelic colour cycling (38;5;N)
          local color=$(( (x + colorShift) % 256 ))
          line+="\033[38;5;${color}m█"
        else
          line+=" "
        fi
      done
      line+="\033[0m"   # reset

      # Print with horizontal offset and message
      printf "\r\033[0K%*s%s \033[1m%s\033[0m" "$offset" "" "$line" "$FL_MSG"

      # Update animation state
      ((row+=rowDir))
      ((row==maxDepth || row==0)) && rowDir=$(( -rowDir ))    # fade in/out

      ((offset+=offDir))
      ((offset<=0 || offset>=width/2)) && offDir=$(( -offDir )) # glide back

      ((colorShift++))

      sleep 0.05
    done
  } &
  FL_PID=$!
}

rad_spinner2_update() {
  if kill -0 "${FL_PID:-0}" 2>/dev/null; then
    printf "%s\n" "$*" >&3
  fi
}

rad_spinner2_stop() {
  if kill -0 "${FL_PID:-0}" 2>/dev/null; then
    kill "$FL_PID" && wait "$FL_PID" 2>/dev/null
  fi
  exec 3>&-                 # close pipe
  tput cnorm                # show cursor
  printf "\r\033[32m✔ Done.\033[0m\n"
  trap - INT
}

rad_spinner2_test() {
  _rad_spinner_test rad_spinner2 ${1:-2}
}

###############################################################################
# End of fractaloader snippet                                                 #
###############################################################################
