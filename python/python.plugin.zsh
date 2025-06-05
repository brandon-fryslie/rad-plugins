#### python - opinionated and functional


############### direnv ###############
#####################################
if command -v direnv &> /dev/null; then
  eval "$(/opt/homebrew/bin/direnv hook zsh)"
else
  rad-yellow "rad-python plugin: direnv is not installed.  consider installing it"
fi
# /direnv


############### pyenv ###############
#####################################
# Only proceed if pyenv exists
if command -v pyenv >/dev/null; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"

  # Ensure pyenv is initialized by checking if `pyenv global` works
  if ! command -v pyenv >/dev/null || [[ -z "$(pyenv root)" ]]; then
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
  fi

  # Initialize pyenv-virtualenv only if available
  if command -v pyenv-virtualenv-init >/dev/null; then
    eval "$(pyenv virtualenv-init -)"
  fi
fi


############### pipenv ###############
#####################################
# Set PIPENV_SHELL to zsh to ensure pipenv uses zsh
export PIPENV_SHELL=zsh

# pipenv completions
if command -v pipenv &> /dev/null; then
  eval "$(_PIPENV_COMPLETE=zsh_source pipenv)"
fi


############### pipx ###############
#####################################
# load pipx completions
if command -v pipx &> /dev/null; then
  eval "$(register-python-argcomplete pipx)"
fi
