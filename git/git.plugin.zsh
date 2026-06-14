script_dir="${0:a:h}"

if [[ -n "$ZSH_VERSION" ]]; then
  [[ -f "${0:a:h}/git-zaw.zsh" ]] && source "${0:a:h}/git-zaw.zsh"
  [[ -f "${0:a:h}/git-status-zaw.zsh" ]] && source "${0:a:h}/git-status-zaw.zsh"
  [[ -f "${0:a:h}/git-branch-zaw.zsh" ]] && source "${0:a:h}/git-branch-zaw.zsh"
  [[ -f "${0:a:h}/git-worktree.zsh" ]] && source "${0:a:h}/git-worktree.zsh"
  [[ -f "${0:a:h}/git-worktree-zaw.zsh" ]] && source "${0:a:h}/git-worktree-zaw.zsh"
fi

rad_plugin_init_hooks+=("rad_git_plugin_init_hook:${script_dir}")

rad_git_plugin_init_hook() {
  local script_dir=$1
  [[ -d "${script_dir}/bin" ]] && export PATH="$PATH:$(rad-realpath "${script_dir}/bin")"
  export GIT_EDITOR="$(rad-get-editor)"

  if type 'hub' &>/dev/null; then
    alias git=hub
  fi

  if type 'git' &>/dev/null; then
    git config --global alias.co checkout
    git config --global alias.st status
  fi

  # Register worktree completions (runs after compinit)
  if (( $+functions[compdef] )); then
    compdef _wt-diff wt-diff
    compdef _wt-push wt-push
    compdef _wt-pull wt-pull
    compdef _gwt gwt
    compdef _gwt-alias gws gwd gwds gwa gwc gwl gwst
  fi
}

alias gb="git for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'"
alias gd="git diff"
alias gds="git diff --staged"
alias git-amend="git commit --amend --no-edit --reset-author"
alias gl="git pull"
alias gs="git status"
alias gst="git stash"
alias lg="git log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%C(bold blue)<%an>%Creset' --abbrev-commit"

alias gdst="git diff --stat"

git-get-default-branch() {
  local candidate

  # [LAW:no-silent-failure] fast path: symbolic ref set by 'git remote set-head origin -a'
  candidate="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')"
  [[ -n "${candidate}" ]] && { echo "${candidate}"; return }

  # [LAW:no-silent-failure] network fallback: ask the remote directly
  candidate="$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')"
  [[ -n "${candidate}" ]] && { echo "${candidate}"; return }

  git rev-parse --verify --quiet "main" >/dev/null 2>&1 && { echo "main"; return }
  git rev-parse --verify --quiet "master" >/dev/null 2>&1 && { echo "master"; return }

  rad-red "git-get-default-branch: cannot determine default branch for this repo"
  return 1
}

really-really-amend() {
  local branch_name="$(git rev-parse --abbrev-ref HEAD)"
  local upstream_remote

  if [[ -n $1 ]]; then
    upstream_remote=$1
  else
    # Read the tracked remote from its authoritative source. Parsing it out of
    # the "remote/branch" abbrev-ref string breaks on branch names with slashes.
    upstream_remote="$(git config --get "branch.${branch_name}.remote")"

    [[ -z $upstream_remote ]] && upstream_remote=origin

    if [[ $upstream_remote != origin ]] && [[ $upstream_remote != upstream ]]; then
      rad-red "Not force pushing to upstream '$upstream_remote'"
      return 1
    fi
  fi

  local default_branch
  default_branch="$(git-get-default-branch)"

  if [[ "${branch_name}" == "${default_branch}" ]]; then
    rad-red "ERROR: Do not force push on the default branch (branch: ${default_branch})"
    return 1
  fi

  git add .

  # Amend commit if there were changes
  if ! git diff-index --quiet HEAD --; then
    git commit --amend --no-edit --reset-author
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
