layzsh_get_root() {
  local layzsh_root="$HOME/.config/layzsh"
  mkdir -p "${layzsh_root}"
  echo "${layzsh_root}"
}

# Function to lint shell scripts using shellcheck
lint_shell_script() {
  if [[ -z "$1" ]]; then
    echo "Usage: lint_shell_script <script_file>"
    return 1
  fi

  if ! command -v shellcheck &> /dev/null; then
    echo "Error: shellcheck is not installed. Please install it first."
    return 1
  fi

  shellcheck "$1"
}

# Optionally, create an alias for convenience
alias lintsh=lint_shell_script

layzsh_init_history_file() {
  local history_type=$1
  local f=$2
  [[ -z "${f}" ]] || [[ -z "${history_type}" ]] && { rad-red "ERROR: argument to layzsh_init_history_file is empty"; return 1; }

  # there are 3 history file types, each with a different 'header prompt'.  each file has the oldest data at the top and the newest at the bottom
  # please write these prompts for me.  come up with a suitable structure for these files and write each prompt as a heredoc that is assigned to the variable defined below
  local chat_history_prompt
  chat_history_prompt=$(cat << 'EOF'
This file contains our chat history for this session. The file is structured with each message and response pair delimited by lines containing %%%.
EOF
)

  local shell_history_prompt
  shell_history_prompt=$(cat << 'EOF'
This file contains the shell commands run during this session, along with the output of those commands. Each command/output pair is delimited by lines containing ###.
EOF
)

  local shell_replacement_history_prompt
  shell_replacement_history_prompt=$(cat << 'EOF'
This file contains the history of inline prompts to generate shell commands, and the generated commands. Each prompt/response pair is delimited by lines containing ***.
EOF
)



  # Initialize the correct file based on the history_type
  case "${history_type}" in
    chat) echo "${chat_history_prompt}" > "${f}";;
    shell) echo "${shell_history_prompt}" > "${f}";;
    shell-replacement) echo "${shell_replacement_history_prompt}" > "${f}";;
    *) rad-red "ERROR: Unknown history type: ${history_type}"; return 1;;
  esac
}

layzsh_get_history_file() {
  # history_type can be either 'chat', 'shell', or 'shell-replacement'
  # chat: conversational chat history, a la chatgpt
  # shell: shell commands that were run and the output of those commands
  # shell-replacement: history of the on-the-fly AI-generated shell commands (the prompt and the response)
  local history_type=$1
  local session_id=$$

  [[ ! " chat shell shell-replacement " =~ " $history_type " ]] && {
    rad-red "Error: Invalid history_type: ${history_type}.  Must be one of chat, shell, or shell-replacement"; return 1;
    }
  local history_file_path="$(layzsh_get_root)/lazysh-history-${history_type}-${session_id}.log"
  [[ ! -f "${history_file_path}" ]] && layzsh_init_history_file "${history_type}" "${history_file_path}"
  echo "${history_file_path}"
}


### Bind all self-insert keys
_layzsh_bind_all_self_insert() {
  local callback=$1
  typeset -f -- "$callback" >/dev/null || { rad-red "ERROR: _layzsh_bind_all_self_insert first parameter must be callback"; return 1; }

  rad-yellow "RAD-SHELL: Not implemented"; return 1;

  zle -N my-self-insert

  function my-self-insert() {
    print -u2 "Pressed: $KEYS"
    zle .self-insert  # call the original built-in self-insert
  }

  # Rebind all self-insert keys
  for key in ${(k)widgets}; do
    (( $+widgets[$key] )) || continue
  done

  for key seq in ${(k)$(bindkey -M emacs)}; do
    if [[ ${(v)$(bindkey -M emacs "$key seq")} == self-insert ]]; then
      bindkey -M emacs "$key seq" my-self-insert
    fi
  done
}
