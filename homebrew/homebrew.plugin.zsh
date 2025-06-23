#### Plugin for Homebrew

### macOS only currently
### Configures homebrew $PATH

if [[ $(uname) == 'Darwin' ]]; then
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
