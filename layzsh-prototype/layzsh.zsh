# ~~~ ~/.zshrc ~~~

#####################################
# 1) Keybinding to start a conversation
#####################################

function start_llm_conversation() {
  emulate -L zsh
  setopt localoptions no_aliases

  # Generate a unique ID for this conversation
  local cid="conv_$(date +%s)_$$"
  local logfile="/tmp/${cid}.log"

  echo ">>> Starting an LLM conversation in a subshell."
  echo ">>> Conversation ID: ${cid}"
  echo ">>> Log file: ${logfile}"
  echo ">>> Type 'exit' (or Ctrl-D) in the conversation shell to return here."

  # We set an environment variable so the subshell knows to load conversation-specific config
  export LLM_CONVERSATION_MODE="1"

  # Start a new shell under 'script'. This ensures only this conversation is recorded.
  script -q -F "${logfile}" zsh -l

  # Once the subshell is exited, script stops recording. We revert the environment variable.
  unset LLM_CONVERSATION_MODE

  echo ">>> Conversation ended. Log saved at ${logfile}."
}

# Bind to Ctrl+G (or your preferred key)
zle -N start_llm_conversation
bindkey '^g' start_llm_conversation

#####################################
# 2) Conditionally load the conversation config
#####################################
# If the LLM_CONVERSATION_MODE variable is set, we source the special config
# that defines the conversation ZLE widgets. This is only relevant to the
# conversation subshell.
if [[ -n "$LLM_CONVERSATION_MODE" ]]; then
  source "${0:a:h}/layzsh_zshrc_subshell.zsh"
fi

# -----------
# run_scripted_command: Run a single command in a fresh Zsh under `script`
# -----------
function run_scripted_command() {
  # Usage: run_scripted_command <conversation_id> <command_string>
  local convo_id="$1"
  local cmd="$2"

  # Generate a unique file for this command
  local timestamp=$(date +%s)
  local tmp_dir="/tmp/convo_logs_${convo_id}"
  mkdir -p "$tmp_dir"
  local logfile="${tmp_dir}/cmd_${timestamp}.$$"

  echo "Running command in ephemeral shell..."
  echo "Logfile: $logfile"

  # Launch ephemeral Zsh under script.
  # -q => quiet (no 'Script started' spam)
  # There's no flush option here (BSD might differ).
  # We'll parse the log only after completion anyway.
  script -q "$logfile" zsh -c "$cmd"

  # Now $logfile is finalized. We can parse it immediately.

  # 1) Strip control characters (ANSI escapes, etc.)
  # This example uses sed to remove common control codes.
  # For a robust approach, consider 'col -b' or 'ansi2txt' or a Python script:
  local cleaned_log="${logfile}.cleaned"
  sed $'s/\x1B\\[[0-9;]*[A-Za-z]//g' "$logfile" > "$cleaned_log"

  # 2) Append to a "master" conversation log or keep in memory
  cat "$cleaned_log" >> "${tmp_dir}/conversation_master.log"

  echo "[Command Output Appended to Master Log]"
  echo "[You can feed the cleaned output to your LLM or handle it further]"
}

# Example usage:
# run_scripted_command "12345" "echo Hello && ls -l"
