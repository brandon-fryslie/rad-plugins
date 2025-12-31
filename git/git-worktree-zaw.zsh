# Git worktree zaw source
# Key binding: Ctrl+Alt+Shift+W
#
# Usage:
#   Ctrl+Alt+Shift+W - open worktree menu
#   Enter            - cd to worktree (default action)
#   Alt+Enter        - open action menu to choose:
#                        cd, status, diff, push, pull, sync, add, commit, log, open in editor
#
# Most actions will show output then re-open the menu for additional actions.

bindkey '^[^W' zaw-git-worktree

function zaw-src-git-worktree() {
    if ! git rev-parse --git-dir &>/dev/null; then
        return
    fi

    local current_branch wt_path wt_branch wt_head line ahead behind status_str visible_name
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

    local title="Worktrees (relative to: $current_branch)"
    local -a cands descs

    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
            wt_path="${match[1]}"
        elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
            wt_branch="${match[1]}"
        elif [[ -z "$line" ]] && [[ -n "$wt_path" ]]; then
            # Get commit SHA for accurate ahead/behind
            wt_head="$(git -C "$wt_path" rev-parse HEAD 2>/dev/null)"

            # Handle detached HEAD
            if [[ -z "$wt_branch" ]]; then
                visible_name="${wt_path:t} (detached)"
                wt_branch="HEAD"
            else
                visible_name="$wt_branch"
            fi

            # Compute ahead/behind using commit SHA
            ahead=$(git rev-list --count "${current_branch}..${wt_head}" 2>/dev/null || echo "?")
            behind=$(git rev-list --count "${wt_head}..${current_branch}" 2>/dev/null || echo "?")

            if [[ "$wt_path" == "$(pwd)" ]]; then
                status_str="(current)"
            else
                status_str=""
                [[ "$ahead" != "0" && "$ahead" != "?" ]] && status_str="+${ahead}"
                if [[ "$behind" != "0" && "$behind" != "?" ]]; then
                    [[ -n "$status_str" ]] && status_str+="/"
                    status_str+="-${behind}"
                fi
                [[ -z "$status_str" ]] && status_str="="
            fi

            # Candidate: path (used by actions to find worktree)
            cands+=("$wt_path")
            # Description: name + status + path
            descs+=("$(printf '%-35s %10s  %s' "$visible_name" "$status_str" "$wt_path")")

            wt_path=""
            wt_branch=""
        fi
    done < <(git worktree list --porcelain 2>/dev/null; echo "")

    : ${(A)candidates::=${cands[@]}}
    : ${(A)cand_descriptions::=${descs[@]}}

    actions=(
        zaw-gwt-cd
        zaw-gwt-status
        zaw-gwt-diff
        zaw-gwt-push
        zaw-gwt-pull
        zaw-gwt-sync
        zaw-gwt-add
        zaw-gwt-commit
        zaw-gwt-log
        zaw-gwt-open-editor
        zaw-rad-append-to-buffer
    )
    act_descriptions=(
        "cd to worktree"
        "show status"
        "show diff"
        "push to worktree"
        "pull from worktree"
        "sync (push+pull)"
        "add all files"
        "commit"
        "show log"
        "open in editor"
        "append path to buffer"
    )
    options=(-t "$title")
}

# Helper: get worktree name from path for gwt commands
function _zaw-gwt-name() {
    echo "${1:t}"
}

# cd to the selected worktree
function zaw-gwt-cd() {
    BUFFER="cd ${(q)1}"
    zle accept-line
}

# Show status - runs command and re-opens zaw
function zaw-gwt-status() {
    local name="$(_zaw-gwt-name "$1")"
    zle -R "Running: gwt $name status..."
    git -C "$1" status
    echo ""
    echo "Press any key to continue..."
    read -k 1
    zle reset-prompt
    zaw-git-worktree
}

# Show diff - runs command and re-opens zaw
function zaw-gwt-diff() {
    local name="$(_zaw-gwt-name "$1")"
    zle -R "Running: gwt $name diff..."
    git -C "$1" diff
    echo ""
    echo "Press any key to continue..."
    read -k 1
    zle reset-prompt
    zaw-git-worktree
}

# Push to worktree - runs command and re-opens zaw
function zaw-gwt-push() {
    local name="$(_zaw-gwt-name "$1")"
    zle -R "Running: gwt-push $name..."
    gwt-push "$name"
    echo ""
    echo "Press any key to continue..."
    read -k 1
    zle reset-prompt
    zaw-git-worktree
}

# Pull from worktree - runs command and re-opens zaw
function zaw-gwt-pull() {
    local name="$(_zaw-gwt-name "$1")"
    zle -R "Running: gwt-pull $name..."
    gwt-pull "$name"
    echo ""
    echo "Press any key to continue..."
    read -k 1
    zle reset-prompt
    zaw-git-worktree
}

# Sync with worktree - runs command and re-opens zaw
function zaw-gwt-sync() {
    local name="$(_zaw-gwt-name "$1")"
    zle -R "Running: gwt-sync $name..."
    gwt-sync "$name"
    echo ""
    echo "Press any key to continue..."
    read -k 1
    zle reset-prompt
    zaw-git-worktree
}

# Add all files in worktree
function zaw-gwt-add() {
    local name="$(_zaw-gwt-name "$1")"
    zle -R "Running: gwt $name add ."
    git -C "$1" add .
    echo "Added all files in $name"
    git -C "$1" status --short
    echo ""
    echo "Press any key to continue..."
    read -k 1
    zle reset-prompt
    zaw-git-worktree
}

# Commit in worktree - drops to command line for message input
function zaw-gwt-commit() {
    local name="$(_zaw-gwt-name "$1")"
    BUFFER="git -C ${(q)1} commit"
    zle accept-line
}

# Show log - runs command and re-opens zaw
function zaw-gwt-log() {
    local name="$(_zaw-gwt-name "$1")"
    zle -R "Running: gwt $name log..."
    git -C "$1" log --oneline -20
    echo ""
    echo "Press any key to continue..."
    read -k 1
    zle reset-prompt
    zaw-git-worktree
}

# Open worktree in editor
function zaw-gwt-open-editor() {
    BUFFER="${EDITOR:-code} ${(q)1}"
    zle accept-line
}

zaw-register-src -n git-worktree zaw-src-git-worktree
