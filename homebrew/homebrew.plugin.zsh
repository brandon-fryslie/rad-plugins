#### Plugin for Homebrew

### macOS only
### adds /usr/local/bin to your $PATH
### Installs Homebrew if not already installed

rad-install-homebrew() {
  rad-red "Installing Homebrew"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

if [[ $(uname) == 'Darwin' ]]; then
  if [[ -x /usr/local/bin/brew ]]; then
    export PATH="/usr/local/bin:$PATH"
  else
    rad-install-homebrew
  fi
fi
