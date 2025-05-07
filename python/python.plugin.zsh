#### python - opinionated and functional

# TODO:
# setup: pipenv, pyenv, direnv


# direnv
_direnv_hook() {
  trap -- '' SIGINT
  eval "$("/opt/homebrew/bin/direnv" export zsh)"
  trap - SIGINT
}
typeset -ag precmd_functions
if (( ! ${precmd_functions[(I)_direnv_hook]} )); then
  precmd_functions=(_direnv_hook $precmd_functions)
fi
typeset -ag chpwd_functions
if (( ! ${chpwd_functions[(I)_direnv_hook]} )); then
  chpwd_functions=(_direnv_hook $chpwd_functions)
fi
# /direnv

# load pipx completions
if command -v pipx &> /dev/null; then
  eval "$(register-python-argcomplete pipx)"
fi
