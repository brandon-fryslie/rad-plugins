#### Plugin for Homebrew

### macOS only
### adds /usr/local/bin to your $PATH
### Installs Homebrew if not already installed

rad-install-homebrew() {
  rad-red "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

if [[ $(uname) == 'Darwin' ]]; then
  if ! type brew &>/dev/null; then
    rad-install-homebrew
  fi
  if [[ -f /opt/homebrew/bin/brew ]]; then
    # Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    # Intel Mac
    eval "$(/usr/local/bin/brew shellenv)"
  else
    rad-red "rad-plugin homebrew: Could not load homebrew shell environment"
  fi
fi
