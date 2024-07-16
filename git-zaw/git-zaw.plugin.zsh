script_dir="${0:a:h}"

if [[ -n "$ZSH_VERSION" ]]; then
  [[ -f "${0:a:h}/git-zaw.zsh" ]] && source "${0:a:h}/git-zaw.zsh"
  [[ -f "${0:a:h}/git-status-zaw.zsh" ]] && source "${0:a:h}/git-status-zaw.zsh"
  [[ -f "${0:a:h}/git-branch-zaw.zsh" ]] && source "${0:a:h}/git-branch-zaw.zsh"
fi
