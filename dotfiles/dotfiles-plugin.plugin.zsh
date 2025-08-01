#### Plugin for working on your dotfiles

### DOTFILES_DIR - set this environment variable to the directory where you
### keep your dotfiles.  Used by the following commands
### Requires the variable $DOTFILES_DIR to be set

### .rc - alias that launches a new zsh so you can see changes in your config
alias .rc="exec zsh"

### cd.rc - change directories to $DOTFILES_DIR
cd.rc() { cd "$DOTFILES_DIR" }

### e.rc - open DOTFILES_DIR in your visual editor
e.rc() { $(rad-get-visual-editor) $DOTFILES_DIR; }

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
