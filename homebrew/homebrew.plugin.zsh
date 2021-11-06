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
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
