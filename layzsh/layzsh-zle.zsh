# zle configuration for layzsh


# Function to log the command before execution
layzsh_preexec() {
  local history_file="$(layzsh_get_history_file "shell")"
  echo "###" >> "${history_file}"
  echo "Command: $1" >> "${history_file}"

  local ts=$(date +%s%3N)
  ZSH_CMD_LOG_FILE="$ZSH_CMD_LOG_DIR/$ts.log"
  ZSH_CMD_BUFFER="$1"
  echo "\$ $1" > "${history_file}"

  # Start tee in background to intercept all output
  exec > >(tee -a "${history_file}") 2>&1
}

# Function to log the output of the command
layzsh_precmd() {
  local history_file="$(layzsh_get_history_file "shell")"
  echo "###" >> "${history_file}"

  # Restore stdout/stderr to terminal
  exec 1>&- 2>&-
  exec > /dev/tty 2> /dev/tty
}

# Ensure these functions are used by Zsh
autoload -Uz add-zsh-hook
add-zsh-hook preexec layzsh_preexec
add-zsh-hook precmd layzsh_precmd
