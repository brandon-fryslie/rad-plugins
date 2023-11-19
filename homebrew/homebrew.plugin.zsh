#### Plugin for Homebrew

### macOS only
### adds /usr/local/bin to your $PATH
### Installs Homebrew if not already installed

rad-install-homebrew() {
  rad-red "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

rad-check-homebrew-installed() {
  # Check for homebrew installation
  local cands=(/opt/homebrew/bin/brew /usr/local/bin/brew)
  local brew_found=false
  local brew_shellenv_returncode=none

  # Check for exiting 'brew' executables
  for cand in "${cands[@]}"; do
    # If we detected a 'brew' executable, but the 'brew' executable is not on the path, we must evaluate the shellenv
    [[ -x "$cand" ]] && ! type brew &>/dev/null && { brew_found=true; eval "$($cand shellenv)"; brew_shellenv_returncode=$?; }
    if [[ $brew_found == "true" ]]; then
      [[ $brew_shellenv_returncode == 0 ]] && break || rad-red "ERROR: failed to evaluate existing homebrew shellenv using path: ${cand}.  Please check homebrew installation"
    fi
  done

  # If none found, install homebrew
  if [[ $brew_found == "false" ]]; then
    rad-install-homebrew
  fi
}

if [[ $(uname) == 'Darwin' ]]; then
  rad-check-homebrew-installed
fi
