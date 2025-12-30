# YAATMGWTM
echo "Loading git-worktree.zsh"
_wt-find-dir() {
  # input:
  # $1: worktree name (directory basename or branch name)
  # output: worktree dir path (prints to stdout)
  # returns: 0 on success, 1 if not found

  local search_name="$1"
  [[ -z "$search_name" ]] && return 1

  local worktree_path=""
  local current_path=""
  local line_prefix line_value

  # Parse git worktree list --porcelain output
  # Format:
  #   worktree /path/to/worktree
  #   HEAD <sha>
  #   branch refs/heads/<branch>
  #   (blank line)
  while IFS= read -r line; do
    line_prefix="${line%% *}"
    line_value="${line#* }"

    if [[ "$line_prefix" == "worktree" ]]; then
      current_path="$line_value"
      # Check if basename matches
      if [[ "${current_path:t}" == "$search_name" ]]; then
        worktree_path="$current_path"
        break
      fi
    elif [[ "$line_prefix" == "branch" ]]; then
      # Extract branch name from refs/heads/<branch>
      local branch_name="${line_value#refs/heads/}"
      if [[ "$branch_name" == "$search_name" ]]; then
        worktree_path="$current_path"
        break
      fi
    fi
  done < <(git worktree list --porcelain)

  if [[ -n "$worktree_path" ]]; then
    echo "$worktree_path"
    return 0
  fi
  return 1
}

# Get list of worktree names (directory basenames) for completion
_wt-list-names() {
  local names=()
  local line
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      names+=("${${match[1]}:t}")
    fi
  done < <(git worktree list --porcelain 2>/dev/null)
  echo "${names[@]}"
}

_wt-diff() {
  _arguments '1:worktree:->wt' '*:git diff args:->diffargs'
  case "$state" in
    wt)
      local wts=($(_wt-list-names))
      _describe 'worktree' wts
      ;;
    diffargs)
      # Fall through to git diff completion
      ;;
  esac
}

_wt-push() {
  _arguments '1:to-worktree:->wt' '2:from-worktree:->wt'
  case "$state" in
    wt)
      local wts=($(_wt-list-names))
      _describe 'worktree' wts
      ;;
  esac
}

_wt-pull() {
  _arguments '1:from-worktree:->wt'
  case "$state" in
    wt)
      local wts=($(_wt-list-names))
      _describe 'worktree' wts
      ;;
  esac
}

wt-diff() {
  # input: worktree name
  # output: git -C /worktree/path diff (diff between changes on worktree and latest commit on worktree)

  if [[ $# -eq 0 ]]; then
    rad-red "Usage: wt-diff <worktree-name> [git diff args...]"
    return 1
  fi

  local wt_name="$1"
  shift

  local wt_dir
  wt_dir="$(_wt-find-dir "$wt_name")"
  if [[ $? -ne 0 ]] || [[ -z "$wt_dir" ]]; then
    rad-red "Error: Could not find worktree '$wt_name'"
    rad-red "Available worktrees:"
    git worktree list
    return 1
  fi

  git -C "$wt_dir" diff "$@"
}

# push commits to another worktree
wt-push() {
  # input:
  #   1 arg: worktree name (to-wt)
  #   2 args: from-wt to-wt (wt names)
  # result:
  # - fails if any uncommitted changes on from-wt
  # - warns if uncommitted changes on to-wt
  # - designed to be run from main wt of repo but can run from any wt
  # - 1 arg form: use current dir as 'from-wt' and arg as 'to-wt'
  # - 2 arg form: specify both from-wt and to-wt

  if [[ $# -eq 0 ]]; then
    rad-red "Usage: wt-push <to-worktree> [from-worktree]"
    rad-red "  Pushes commits from current (or specified) worktree to target"
    return 1
  fi

  local from_wt_dir to_wt_dir from_wt_name to_wt_name

  if [[ $# -eq 1 ]]; then
    # 1 arg: current dir is from-wt, arg is to-wt
    from_wt_dir="$(pwd)"
    from_wt_name="(current)"
    to_wt_name="$1"
  else
    # 2 args: from-wt to-wt
    from_wt_name="$1"
    to_wt_name="$2"
    from_wt_dir="$(_wt-find-dir "$from_wt_name")"
    if [[ $? -ne 0 ]] || [[ -z "$from_wt_dir" ]]; then
      rad-red "Error: Could not find source worktree '$from_wt_name'"
      rad-red "Available worktrees:"
      git worktree list
      return 1
    fi
  fi

  # Find the to-wt directory
  to_wt_dir="$(_wt-find-dir "$to_wt_name")"
  if [[ $? -ne 0 ]] || [[ -z "$to_wt_dir" ]]; then
    rad-red "Error: Could not find target worktree '$to_wt_name'"
    rad-red "Available worktrees:"
    git worktree list
    return 1
  fi

  # Check for uncommitted changes on from-wt - FAIL if any
  if [[ -n "$(git -C "$from_wt_dir" status --porcelain)" ]]; then
    rad-red "Error: Uncommitted changes in source worktree '$from_wt_name'"
    rad-red "  Commit or stash changes before pushing"
    git -C "$from_wt_dir" status --short
    return 1
  fi

  # Check for uncommitted changes on to-wt - WARN if any
  if [[ -n "$(git -C "$to_wt_dir" status --porcelain)" ]]; then
    rad-yellow "Warning: Uncommitted changes in target worktree '$to_wt_name'"
    rad-yellow "  These may cause conflicts"
    git -C "$to_wt_dir" status --short
    echo ""
  fi

  # Get branch names
  local from_branch to_branch
  from_branch="$(git -C "$from_wt_dir" rev-parse --abbrev-ref HEAD)"
  to_branch="$(git -C "$to_wt_dir" rev-parse --abbrev-ref HEAD)"

  # Check if there are commits to push
  local commit_count
  commit_count="$(git -C "$from_wt_dir" rev-list --count "$to_branch".."$from_branch" 2>/dev/null)"

  if [[ "$commit_count" -eq 0 ]]; then
    rad-green "No new commits to push from '$from_wt_name' ($from_branch) to '$to_wt_name' ($to_branch)"
    return 0
  fi

  rad-green "Pushing $commit_count commit(s) from '$from_wt_name' ($from_branch) to '$to_wt_name' ($to_branch)"
  git -C "$from_wt_dir" log --oneline "$to_branch".."$from_branch"
  echo ""

  # Pull with rebase in the target worktree from the source branch
  if ! git -C "$to_wt_dir" pull --rebase . "$from_branch" 2>/dev/null; then
    _wt-resolve-conflicts "$to_wt_dir" || return 1
  fi

  rad-green "Successfully pushed to '$to_wt_name' ($to_branch)"
}

# pull changes from a wt to current branch
wt-pull() {
  # input:
  #   1 arg: worktree name (from wt)
  #   2 args: not valid (use wt-push 2 arg form)
  # result:
  # - fails if any uncommitted changes on to-wt
  # - warns if uncommitted changes on from-wt
  # - designed to be run from main wt of repo but can run from any wt
  # - 1 arg form: use current dir as 'to-wt' and arg as 'from-wt'

  if [[ $# -eq 0 ]]; then
    rad-red "Usage: wt-pull <worktree-name>"
    rad-red "  Pulls commits from the specified worktree into current branch"
    return 1
  fi

  if [[ $# -gt 1 ]]; then
    rad-red "Error: wt-pull only accepts 1 argument"
    rad-red "  For 2-arg form, use: wt-push <from-wt> <to-wt>"
    return 1
  fi

  local from_wt_name="$1"
  local to_wt_dir="$(pwd)"

  # Find the from-wt directory
  local from_wt_dir
  from_wt_dir="$(_wt-find-dir "$from_wt_name")"
  if [[ $? -ne 0 ]] || [[ -z "$from_wt_dir" ]]; then
    rad-red "Error: Could not find worktree '$from_wt_name'"
    rad-red "Available worktrees:"
    git worktree list
    return 1
  fi

  # Check for uncommitted changes on to-wt (current dir) - FAIL if any
  if [[ -n "$(git -C "$to_wt_dir" status --porcelain)" ]]; then
    rad-red "Error: Uncommitted changes in current worktree"
    rad-red "  Commit or stash changes before pulling"
    git -C "$to_wt_dir" status --short
    return 1
  fi

  # Check for uncommitted changes on from-wt - WARN if any
  if [[ -n "$(git -C "$from_wt_dir" status --porcelain)" ]]; then
    rad-yellow "Warning: Uncommitted changes in source worktree '$from_wt_name'"
    rad-yellow "  These changes will NOT be included in the pull"
    git -C "$from_wt_dir" status --short
    echo ""
  fi

  # Get branch names
  local to_branch from_branch
  to_branch="$(git -C "$to_wt_dir" rev-parse --abbrev-ref HEAD)"
  from_branch="$(git -C "$from_wt_dir" rev-parse --abbrev-ref HEAD)"

  # Check if there are commits to pull
  local commit_count
  commit_count="$(git -C "$to_wt_dir" rev-list --count "$to_branch".."$from_branch" 2>/dev/null)"

  if [[ "$commit_count" -eq 0 ]]; then
    rad-green "No new commits to pull from '$from_wt_name' ($from_branch)"
    return 0
  fi

  rad-green "Pulling $commit_count commit(s) from '$from_wt_name' ($from_branch) into $to_branch"
  git -C "$to_wt_dir" log --oneline "$to_branch".."$from_branch"
  echo ""

  # Pull with rebase from the local branch
  if ! git -C "$to_wt_dir" pull --rebase . "$from_branch" 2>/dev/null; then
    _wt-resolve-conflicts "$to_wt_dir" || return 1
  fi

  rad-green "Successfully pulled from '$from_wt_name' ($from_branch)"
}

_wt-resolve-conflicts() {
  local repo_dir="$1"
  local conflicted_files

  while true; do
    conflicted_files=(${(f)"$(git -C "$repo_dir" diff --name-only --diff-filter=U 2>/dev/null)"})
    [[ ${#conflicted_files[@]} -eq 0 ]] && break

    rad-yellow "Conflicts in ${#conflicted_files[@]} file(s):"
    printf '  %s\n' "${conflicted_files[@]}"
    echo ""

    for file in "${conflicted_files[@]}"; do
      _wt-resolve-single-conflict "$repo_dir" "$file" || return 1
    done

    # Continue the rebase
    if ! git -C "$repo_dir" rebase --continue 2>/dev/null; then
      # More conflicts from next commit, loop again
      continue
    fi
    break
  done
  return 0
}

_wt-resolve-single-conflict() {
  local repo_dir="$1"
  local file="$2"
  local full_path="$repo_dir/$file"

  echo ""
  rad-yellow "=== Conflict in: $file ==="
  echo ""

  # Show the conflict
  cat "$full_path"
  echo ""

  while true; do
    echo "How to resolve?"
    echo "  [o] Keep ours (current branch)"
    echo "  [t] Keep theirs (incoming branch)"
    echo "  [l] LLM resolve (OpenAI)"
    echo "  [e] Edit manually"
    echo "  [s] Skip (leave conflicted)"
    echo "  [a] Abort rebase"
    echo ""
    read -k 1 "choice?Choice: "
    echo ""

    case "$choice" in
      o|O)
        git -C "$repo_dir" checkout --ours "$file"
        git -C "$repo_dir" add "$file"
        rad-green "Kept ours for $file"
        return 0
        ;;
      t|T)
        git -C "$repo_dir" checkout --theirs "$file"
        git -C "$repo_dir" add "$file"
        rad-green "Kept theirs for $file"
        return 0
        ;;
      l|L)
        if _wt-llm-resolve "$repo_dir" "$file"; then
          git -C "$repo_dir" add "$file"
          rad-green "LLM resolved $file"
          return 0
        else
          rad-red "LLM could not resolve, choose another option"
        fi
        ;;
      e|E)
        ${EDITOR:-vim} "$full_path"
        if ! grep -q "^<<<<<<< " "$full_path" 2>/dev/null; then
          git -C "$repo_dir" add "$file"
          rad-green "Manually resolved $file"
          return 0
        else
          rad-yellow "Conflict markers still present"
        fi
        ;;
      s|S)
        rad-yellow "Skipping $file (still conflicted)"
        return 0
        ;;
      a|A)
        git -C "$repo_dir" rebase --abort
        rad-red "Rebase aborted"
        return 1
        ;;
      *)
        rad-red "Invalid choice"
        ;;
    esac
  done
}

_wt-llm-resolve() {
  local repo_dir="$1"
  local file="$2"
  local full_path="$repo_dir/$file"

  if [[ -z "$OPENAI_API_KEY" ]]; then
    rad-red "OPENAI_API_KEY not set"
    return 1
  fi

  local content
  content="$(<"$full_path")"

  local prompt="Resolve this git merge conflict. Output ONLY the resolved file content with no explanation, no markdown code blocks, just the raw resolved code. Pick the best combination of both sides or choose one if appropriate.

File: $file

$content"

  local escaped_prompt
  escaped_prompt=$(printf '%s' "$prompt" | jq -Rs .)

  local response
  response=$(curl -s "https://api.openai.com/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "{
      \"model\": \"gpt-4o-mini\",
      \"messages\": [{\"role\": \"user\", \"content\": $escaped_prompt}],
      \"temperature\": 0
    }")

  local resolved
  resolved=$(echo "$response" | jq -r '.choices[0].message.content // empty')

  if [[ -z "$resolved" ]]; then
    rad-red "Empty response from API"
    return 1
  fi

  # Check if response still has conflict markers
  if echo "$resolved" | grep -q "^<<<<<<< \|^=======$\|^>>>>>>> "; then
    rad-red "LLM response still contains conflict markers"
    return 1
  fi

  # Show diff and confirm
  echo ""
  rad-yellow "LLM proposed resolution:"
  echo "$resolved"
  echo ""
  read -k 1 "confirm?Accept this resolution? [y/n]: "
  echo ""

  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo "$resolved" > "$full_path"
    return 0
  fi
  return 1
}

# Completion registration helper for compctl (old system fallback)
_wt-completion-reply() {
  reply=($(_wt-list-names))
}

# Register with compctl - works immediately during plugin load
# The init hook (rad_git_plugin_init_hook) registers with compdef after compinit
compctl -K _wt-completion-reply wt-diff wt-push wt-pull
