bindkey '^[B' zaw-git-branch

#### zaw source for git branches

### key binding: option + shift + B

### Use this to show git branches for repo in current directory
function zaw-src-git-branch() {
    if ! git rev-parse -s 2>/dev/null; then
      return
    fi

    local desc="$(git for-each-ref --sort=-committerdate refs/heads/ --format='%(HEAD) %(refname:short) - %(objectname:short) - %(contents:subject) - %(authorname) (%(committerdate:relative))')"

    local title=$(git branches)
    local cands="$(echo "$desc" | sed 's/^\*//' | awk '{print $3}')"

    : ${(A)candidates::=${(f)cands}}
    : ${(A)cand_descriptions::=${(f)desc}}
    actions=(\
        zaw-src-git-branch-checkout \
        zaw-src-git-branch-reset-hard \
        zaw-rad-append-to-buffer \
    )
    act_descriptions=(\
        "checkout" \
        "reset hard" \
        "append to buffer" \
    )
    options=(-t "$title")
}

# Command functions
function zaw-src-git-branch-checkout() {
    BUFFER="git checkout $1"
    zaw-rad-action ${reply[1]}
}

function zaw-src-git-branch-reset-hard() {
    BUFFER="git reset --hard $1"
    zaw-rad-action ${reply[1]}
}

zaw-register-src -n git-branch zaw-src-git-branch
