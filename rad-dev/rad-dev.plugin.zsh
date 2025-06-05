#### plugin for interacting with rad-shell plugins
source "${0:a:h}/rad-dev-zaw.zsh"

# TODO: implement these somewhere else
# Make them work with zgenom as well
if [[ $ZGEN_DIR =~ zgenom ]]; then
#  rad-yellow "rad-dev: using zgenom"
  _rad_shell_repo_dir="$ZGEN_DIR/brandon-fryslie/rad-shell/___"
  _rad_shell_plugins_repo_dir="$ZGEN_DIR/brandon-fryslie/rad-plugins/___"
else
  rad-rad "rad-dev: using zgen!"
  _rad_shell_repo_dir="$ZGEN_DIR/brandon-fryslie/rad-shell-master"
  _rad_shell_plugins_repo_dir="$ZGEN_DIR/brandon-fryslie/rad-plugins-master"
fi

### cd.rad - change to the rad-shell repo directory
### you can edit the repo and changes will be reflected if you source ~/.zshrc
cd.rad() { cd $_rad_shell_repo_dir; }

### e.rad - Open the rad-shell repository in your VISUAL editor
e.rad() { ${VISUAL:-${EDITOR:-vi}} $_rad_shell_repo_dir; }

### cd.rad-plugins - change to the rad-plugins repo directory
cd.rad-plugins() { cd $_rad_shell_plugins_repo_dir; }

### e.rad-plguins - Edit the rad-shell plugins repo
e.rad-plugins() {
  cd.rad-plugins
  "$(rad-get-visual-editor)" $_rad_shell_plugins_repo_dir
}

