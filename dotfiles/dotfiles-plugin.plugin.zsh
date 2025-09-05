#### Plugin for working on your dotfiles

# Default dotfiles location
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# Initialize dotfiles repository from DOTFILES_REPO if set
if [[ -n "$DOTFILES_REPO" ]]; then
  # Create a timestamp file to track updates
  DOTFILES_TIMESTAMP_FILE="$HOME/.dotfiles_last_update"
  
  # Function to check if we need to update (once per day)
  dotfiles_should_update() {
    if [[ ! -f "$DOTFILES_TIMESTAMP_FILE" ]]; then
      return 0  # No timestamp file, should update
    fi
    
    local last_update=$(cat "$DOTFILES_TIMESTAMP_FILE")
    local current_time=$(date +%s)
    local one_day=86400  # seconds in a day
    
    if (( current_time - last_update > one_day )); then
      return 0  # More than a day has passed, should update
    fi
    
    return 1  # Updated recently, no need to update
  }
  
  # Function to update timestamp
  dotfiles_update_timestamp() {
    date +%s > "$DOTFILES_TIMESTAMP_FILE"
  }
  
  # Function to clone or update the dotfiles repository
  dotfiles_sync() {
    local force=${1:-0}
    
    if [[ ! -d "$DOTFILES_DIR" ]]; then
      rad-yellow "Cloning dotfiles repository from $DOTFILES_REPO to $DOTFILES_DIR"
      git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
      dotfiles_install
    elif [[ "$force" -eq 1 ]] || dotfiles_should_update; then
      if [[ -d "$DOTFILES_DIR/.git" ]]; then
        rad-yellow "Updating dotfiles repository at $DOTFILES_DIR"
        (cd "$DOTFILES_DIR" && git pull)
        dotfiles_install
      fi
    fi
    
    dotfiles_update_timestamp
  }
  
  # Function to install dotfiles using dotbot
  dotfiles_install() {
    if [[ -f "$DOTFILES_DIR/install" && -x "$DOTFILES_DIR/install" ]]; then
      rad-yellow "Running dotfiles installer script"
      (cd "$DOTFILES_DIR" && ./install)
    elif [[ -f "$DOTFILES_DIR/install.conf.yaml" ]]; then
      if ! command -v dotbot >/dev/null 2>&1; then
        rad-yellow "Dotbot not found. Installing dotbot..."
        pip install --user dotbot
      fi
      rad-yellow "Installing dotfiles with dotbot"
      (cd "$DOTFILES_DIR" && dotbot -c install.conf.yaml)
    else
      rad-yellow "No install method found for dotfiles"
    fi
  }
  
  # Run initial sync on plugin load
  dotfiles_sync
fi

### .rc - alias that launches a new zsh so you can see changes in your config
alias .rc="exec zsh"

### cd.rc - change directories to $DOTFILES_DIR
cd.rc() { cd "$DOTFILES_DIR" }

### e.rc - open DOTFILES_DIR in your visual editor
e.rc() { $(rad-get-visual-editor) "$DOTFILES_DIR"; }

### df.sync - Force sync dotfiles from repository
df.sync() { 
  if [[ -z "$DOTFILES_REPO" ]]; then
    rad-red "DOTFILES_REPO environment variable is not set"
    return 1
  fi
  dotfiles_sync 1
}

### df.install - Run dotfiles installer
df.install() { dotfiles_install; }

function gcn() {
  local url=$1

  if [[ -z $url ]]; then
    rad-red "Must provide URL"
    return 1
  fi

  local perl_str='if (m#(git@|ssh|https?:\/\/)([^\/:]+)[\/:]([^\/]+?)\/([^\/]+?)\.git$#) { print "$3_$4"; }'
  local dest_dir="$(echo $url | perl -ne $perl_str)"

  rad-yellow "INFO: Cloning repo '${url}' into destination dir: ${dest_dir}"
  git clone $url $dest_dir
}