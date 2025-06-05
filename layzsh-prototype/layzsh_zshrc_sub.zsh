# ~~~ ~/.zshrc_conversation ~~~

#####################################
# 1) A conversation-specific prompt
#####################################
autoload -Uz promptinit && promptinit
prompt off  # or choose a minimal custom prompt

# Show that we're in a "Conversation Shell"
_setprompt=setprompt
export PS1="%F{magenta}[LLM-Conversation]%f %~ ➜ "

#####################################
# 2) ZLE widgets for LLM flow
#####################################

# Example "menu1" function
function menu1_llm() {
  emulate -L zsh
  setopt localoptions no_aliases

  local user_prompt="$BUFFER"
  # Clear the buffer now that we've captured it
  BUFFER=""
  zle reset-prompt

  # Log the prompt to the terminal output (so 'script' captures it)
  echo "[LLM_PROMPT] $user_prompt"

  # Pretend we call an LLM with $user_prompt
  # (In reality, you'd do:  curl ... or python3 script ... etc.)
  # We'll just mock an explanation and generated command:
  local explanation="(Mock) This command counts lines of code in *.py"
  local generated_cmd="wc -l *.py"

  echo "[LLM_RESPONSE] $explanation"
  echo "[LLM_CMD] $generated_cmd"

  # Show a mini TUI (trivial example)
  echo ""
  echo "--------------- LLM MENU ---------------"
  echo "Command: $generated_cmd"
  echo "Explanation: $explanation"
  echo "Actions: [R] reWord, [I] Insert, [E] Exit"
  echo "----------------------------------------"
  read -k1 choice"?Choose Action: "

  case "$choice" in
    [Rr])
      echo "[LLM_ACTION] reWord"
      # Put the old prompt back for editing
      BUFFER="$user_prompt"
      zle reset-prompt
      ;;
    [Ii])
      echo "[LLM_ACTION] insert"
      # Insert the generated command into BUFFER
      BUFFER="$generated_cmd"
      zle reset-prompt
      ;;
    [Ee])
      echo "[LLM_ACTION] end"
      # Just do nothing, user can type something else or exit
      ;;
    *)
      echo "[LLM_ACTION] unknown"
      ;;
  esac
}

zle -N menu1_llm
bindkey '^x^l' menu1_llm

#####################################
# 3) "menu2" for post-execution analysis
#####################################
function menu2_llm() {
  emulate -L zsh
  setopt localoptions no_aliases

  echo "[LLM_MENU2] triggered"

  # Suppose the user ran the command, we can parse the last command from history or from a variable
  # This is just an example. Real logic might query LLM with the previous command + output.
  local last_cmd=$(fc -ln -1)  # naive approach: last line from history
  echo "Last command was: $last_cmd"
  echo "Enter a new prompt if you'd like to fix/explain, or just press Enter:"
  read -r user_prompt

  if [[ -n "$user_prompt" ]]; then
    echo "[LLM_PROMPT_Menu2] $user_prompt"
    # (Pretend to call LLM again)
    local fix_suggestion="(Mock) Try 'ls -lh *.py'"
    echo "[LLM_RESPONSE_Menu2] $fix_suggestion"
  else
    echo "No new prompt given."
  fi

  echo "Actions: [F] Fix, [E] Explain, [D] Discard"
  read -k1 choice2"?Choose Action: "

  case "$choice2" in
    [Ff])
      echo "[LLM_ACTION_Menu2] fix"
      # Insert fix suggestion in BUFFER
      BUFFER="$fix_suggestion"
      zle reset-prompt
      ;;
    [Ee])
      echo "[LLM_ACTION_Menu2] explain"
      echo "Explanation not implemented. (mocking...)"
      ;;
    [Dd])
      echo "[LLM_ACTION_Menu2] discard"
      echo "Discarding conversation. Type 'exit' to close the conversation shell."
      ;;
    *)
      echo "[LLM_ACTION_Menu2] unknown"
      ;;
  esac
}

zle -N menu2_llm
bindkey '^x^m' menu2_llm

#####################################
# 4) Cleanup / environment sanity
#####################################
# For demonstration, let's remind user how to end:
echo "Welcome to the LLM conversation shell!"
echo "Press Ctrl+X then Ctrl+L to do 'menu1'."
echo "Press Ctrl+X then Ctrl+M to do 'menu2'."
echo "Type 'exit' or press Ctrl+D to end the conversation."

