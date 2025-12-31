# Git worktree zaw source
# Key binding: Alt+W (Option+W on macOS)

bindkey '^[W' zaw-git-worktree

# zaw source for git worktrees
# Lists worktrees with branch, path, and ahead/behind status
function zaw-src-git-worktree() {
    if ! git rev-parse --git-dir &>/dev/null; then
        return
    fi

    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

    local title="git worktrees (relative to: $current_branch)"
    local -a cands descs
    local wt_path wt_branch line ahead behind status_str

    # Parse worktree list
    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
            wt_path="${match[1]}"
        elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
            wt_branch="${match[1]}"
        elif [[ -z "$line" ]] && [[ -n "$wt_path" ]]; then
            if [[ -n "$wt_branch" ]]; then
                # Compute ahead/behind
                ahead=$(git rev-list --count "${current_branch}..${wt_branch}" 2>/dev/null || echo "?")
                behind=$(git rev-list --count "${wt_branch}..${current_branch}" 2>/dev/null || echo "?")

                status_str=""
                if [[ "$wt_branch" == "$current_branch" ]]; then
                    status_str="(current)"
                else
                    [[ "$ahead" != "0" ]] && status_str="+${ahead}"
                    if [[ "$behind" != "0" ]]; then
                        [[ -n "$status_str" ]] && status_str+="/"
                        status_str+="-${behind}"
                    fi
                    [[ -z "$status_str" ]] && status_str="="
                fi

                # Candidate: branch name (used by actions)
                cands+=("$wt_branch")
                # Description: branch + status + path
                descs+=("$(printf '%-35s %8s  %s' "$wt_branch" "$status_str" "$wt_path")")
            fi
            wt_path=""
            wt_branch=""
        fi
    done < <(git worktree list --porcelain 2>/dev/null; echo "")

    : ${(A)candidates::=${cands[@]}}
    : ${(A)cand_descriptions::=${descs[@]}}
    actions=(
        zaw-src-git-worktree-cd
        zaw-src-git-worktree-status
        zaw-src-git-worktree-diff
        zaw-rad-append-to-buffer
    )
    act_descriptions=(
        "cd to worktree"
        "show status"
        "show diff"
        "append to buffer"
    )
    options=(-t "$title")
}

# cd to the selected worktree
function zaw-src-git-worktree-cd() {
    local wt_dir
    wt_dir="$(_wt-find-dir "$1")"
    if [[ -n "$wt_dir" ]]; then
        BUFFER="cd ${(q)wt_dir}"
        zaw-rad-action "${reply[1]}"
    fi
}

# Show status of selected worktree
function zaw-src-git-worktree-status() {
    BUFFER="gws $1"
    zaw-rad-action "${reply[1]}"
}

# Show diff of selected worktree
function zaw-src-git-worktree-diff() {
    BUFFER="gwd $1"
    zaw-rad-action "${reply[1]}"
}

zaw-register-src -n git-worktree zaw-src-git-worktree
