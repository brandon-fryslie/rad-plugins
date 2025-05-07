sgpt_cmd() {
  local history_type=$1
  shift  # Remove the first argument so that "$@" contains only the sgpt command

  if [[ -n "$BUFFER" ]]; then
      BUFFER+="⌛"
      zle -I  # Immediately update the display
      zle redisplay  # Force redisplay to show the hourglass immediately

      local layzsh_prompt=$BUFFER
      local layzsh_response
      local history_file
      local history_content

      # Get the appropriate history file based on the history type
      history_file="$(layzsh_get_history_file "${history_type}")"

      # Read the history content
      history_content=$(<"${history_file}")

      # Include history in the prompt
      layzsh_prompt="${history_content}\nUser prompt: ${layzsh_prompt}"

      layzsh_response="$("$@" <<< "${layzsh_prompt}")"

      # Strip the trailing hourglass emoji from the prompt
      layzsh_prompt="${layzsh_prompt%⌛}"
      echo "***" >> "${history_file}"
      echo "prompt: ${layzsh_prompt}\n" >> "${history_file}"
      echo "response: ${layzsh_response}" >> "${history_file}"
      echo "***\n" >> "${history_file}"

      zle -I
      # Add the prompt to the Zsh history
      print -s -- "${layzsh_prompt}"

      # Print the prompt and response to the terminal with color and effects
      zle redisplay
      echo
      echo -e "\033[1;34m=== Layzsh Prompt ===\033[0m"
      echo -e "\033[1;32m${layzsh_prompt}\033[0m"
      echo -e "\033[1;34m=== Layzsh Response ===\033[0m"
      echo -e "\033[1;32m${layzsh_response}\033[0m\n\n"
      BUFFER="${layzsh_response}"
      zle redisplay
      zle end-of-line
  fi

  zle-line-finish
}

sgpt_zsh_fix() {
  sgpt_cmd sgpt --shell --no-interaction "Prompt: there is a problem with this shell command.  Fix it:"
}

# Shell-GPT integration ZSH v0.2
sgpt_zsh_chat() {
  sgpt_cmd sgpt "you are an expert software engineer who is concise and precise.  User prompt:"
}
