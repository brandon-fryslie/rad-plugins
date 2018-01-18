# Plugin for ensuring homebrew is installed

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
