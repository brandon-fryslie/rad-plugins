source "${0:a:h}/git-zaw.zsh"
source "${0:a:h}/git-status-zaw.zsh"
source "${0:a:h}/git-branch-zaw.zsh"

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
  local upstream_remote

  if [[ -n $1 ]]; then
    upstream_remote=$1
  else
    upstream_remote=${$(git rev-parse --verify "${branch_name}@{upstream}" --symbolic-full-name --abbrev-ref 2>/dev/null)%/*}

    [[ -z $upstream_remote ]] && upstream_remote=origin

    if [[ $upstream_remote != origin ]] && [[ $upstream_remote != upstream ]]; then
      rad-red "Not force pushing to upstream '$upstream_remote'"
      return 1
    fi
  fi

  if [[ $branch_name == master ]]; then
    rad-red "Don't do this on master, dummy"
    return 1
  fi

  git add .

  # Amend commit if there were changes
  if ! git diff-index --quiet HEAD --; then
    git-amend
  fi

  git push -f ${upstream_remote} HEAD:$branch_name
}

### gh-open - open the current directory repo & branch on github
### Constructs the URL for your current repo and branch and opens the URL
function gh-open() {
  local remote_name="${1:-origin}"
  local repo_dir="${2:-`pwd`}"
  local branch_name="$(git -C ${repo_dir} rev-parse --abbrev-ref HEAD)"

  remote_url="$(git -C ${repo_dir} config --local remote.${remote_name}.url)"

  [[ -z $remote_url ]] && { rad-red "gh-open: cannot find remote $remote_name"; return; }

  github_base_url="http://$(echo $remote_url | perl -ne 'if (m/(git|ssh|https?|git@[-\w.]+):(\/\/)?(.*?)(\.git)(\/?|\#[-\d\w._]+?)$/) { $repo = $3; ($domain = $1) =~ s/git@//; print "$domain/$repo"; }')"

  open "$github_base_url/tree/${branch_name}"
}

### Testing this out: opt+shift+o x2 for gh-open
#bindkey '^[O^[O' gh-open
