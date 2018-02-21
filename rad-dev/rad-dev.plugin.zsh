#### plugin for interacting with rad-shell plugins
source "${0:a:h}/rad-dev-zaw.zsh"

### e.rad - Open the rad-shell repository in your VISUAL editor
e.rad() { ${VISUAL:-${EDITOR:-vi}} $HOME/.zgen/brandon-fryslie/rad-shell-master; }

### cd.rad - change to the rad-shell repo directory
### you can edit the repo and changes will be reflected if you source ~/.zshrc
cd.rad() { cd $HOME/.zgen/brandon-fryslie/rad-shell-master; }
