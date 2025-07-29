function zle_log() {
  emulate -L zsh
  setopt extended_glob

  # Args
  local msg="$1"
  local level="${2:-info}"

  # Bail if not a terminal (e.g., redirected output)
  [[ -t 1 ]] || return

  # Style
  local prefix color
  case "$level" in
    info)  prefix="ℹ️ "; color="%F{cyan}";;
    warn)  prefix="⚠️ "; color="%F{yellow}";;
    error) prefix="❌ "; color="%F{red}";;
    debug) prefix="🐞 "; color="%F{blue}";;
    *)     prefix="";   color="%F{white}";;
  esac

  local logfile="/tmp/zle-log.$$.log"

  # Ensure we print on a clean line and then move up
  print -P "${color}${prefix}${msg}%f" >> $logfile
}

_zle_log_flush() {
  local logfile="/tmp/zle-log.$$.log"
  if [[ -e $logfile ]]; then
    print -P # new line
    while IFS= read -r line; do
      print -P -- "$line"
    done < $logfile
    rm -f $logfile
  fi
#  zle -I && zle redisplay
}
#add-zsh-hook precmd _zle_log_flush
