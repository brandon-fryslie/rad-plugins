
#### lazysh - AI assistant in your shell.  Go on, get lazy

source "${0:a:h}/layzsh-util.zsh"
source "${0:a:h}/layzsh-zle.zsh"





layzsh_run_command() {

  local logfile=$1
  local cmd=$2

  echo '---\n'
  echo "command:\n${cmd}\n"

  # use script to capture the output
  echo "output:\n"
  script -q /dev/stdout "${SHELL}" -i -c "${cmd}" >> "${logfile}"
  echo '\n---\n'
}

# replace a prompt inline in your shell
sgpt_zsh() {
  sgpt_cmd sgpt --shell --no-interaction
}
zle -N sgpt_zsh
bindkey '^[i^[i' sgpt_zsh

#
sgpt_zsh_fix() {
  sgpt_cmd sgpt --shell --no-interaction "Prompt: there is a problem with this shell command.  Fix it:"
}
zle -N sgpt_zsh_fix
bindkey '^[i^[j' sgpt_zsh_fix
# Shell-GPT integration ZSH v0.2

