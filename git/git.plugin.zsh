source "${0:a:h}/git-zaw.zsh"
source "${0:a:h}/git-status-zaw.zsh"

export PATH="$PATH:$(rad-realpath "${0:a:h}/bin")"

alias gb="git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"
alias gd="git diff"
alias gds="git diff --staged"
alias git-amend="git commit --amend --no-edit --reset-author"
alias gl="git pull"
alias gs="git status"
alias gst="git stash"
alias lg="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit"

git config --global alias.co checkout
git config --global alias.st status
alias gdstat="git diff --stat"

if type 'hub' &>/dev/null; then
  alias git=hub
fi

export GIT_EDITOR="$(rad-get-editor)"

really-really-amend() {
  local branch_name="$(git rev-parse --abbrev-ref HEAD)"
  local upstream_remote=${$(git rev-parse --verify "${branch_name}@{upstream}" --symbolic-full-name --abbrev-ref 2>/dev/null)%/*}
  [[ -z $upstream_remote ]] && upstream_remote=origin

  if [[ $upstream_remote != origin ]] && [[ $upstream_remote != upstream ]]; then
    red "Not force pushing to upstream '$upstream_remote'"
    return 1
  fi

  if [[ $branch_name == master ]]; then
    red "Don't do this on master, dummy"
    return 1
  fi

  git add . && git-amend && git push -f ${upstream_remote:-origin} HEAD:$branch_name
}
