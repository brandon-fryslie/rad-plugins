# Plugin for developing rad-shell and rad-shell plugins
source "${0:a:h}/rad-dev-zaw.zsh"

e.rad() { ${VISUAL:-${EDITOR:-vi}} $HOME/.zgen/brandon-fryslie/rad-shell-master; }
cd.rad() { cd $HOME/.zgen/brandon-fryslie/rad-shell-master; }
