#### Plugin for working on your dotfiles

### DOTFILES_DIR - set this environment variable to the directory where you
### keep your dotfiles.  Used by the following commands

### .rc - alias that sources your ~/.zshrc file
alias .rc="source $HOME/.zshrc"

### cd.rc - change directories to $DOTFILES_DIR
alias cd.rc="$HOME/dotfiles"

### e.rc - open DOTFILES_DIR in your visual editor
e.rc() { $(rad-get-visual-editor) $HOME/dotfiles; }

