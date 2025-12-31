# Git worktree utilities
# ☢ depends_on shell-customize

_gwt-find-dir() {
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
# Outputs one name per line to handle spaces in names
_gwt-list-names() {
  local line
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      print -r -- "${${match[1]}:t}"
    fi
  done < <(git worktree list --porcelain 2>/dev/null)
}

_gwt-diff() {
  _arguments '1:worktree:->wt' '*:git diff args:->diffargs'
  case "$state" in
    wt)
      local -a wts
      wts=("${(@f)$(_gwt-list-names)}")
      _describe 'worktree' wts
      ;;
    diffargs)
      # Fall through to git diff completion
      ;;
  esac
}

_gwt-push() {
  _arguments '1:to-worktree:->wt' '2:from-worktree:->wt'
  case "$state" in
    wt)
      local -a wts
      wts=("${(@f)$(_gwt-list-names)}")
      _describe 'worktree' wts
      ;;
  esac
}

_gwt-pull() {
  _arguments '1:from-worktree:->wt'
  case "$state" in
    wt)
      local -a wts
      wts=("${(@f)$(_gwt-list-names)}")
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
  wt_dir="$(_gwt-find-dir "$wt_name")"
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
  to_wt_dir="$(_gwt-find-dir "$to_wt_name")"
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
    _gwt-resolve-conflicts "$to_wt_dir" || return 1
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
  from_wt_dir="$(_gwt-find-dir "$from_wt_name")"
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

_gwt-resolve-conflicts() {
  local repo_dir="$1"
  local conflicted_files
  local resolve_result

  while true; do
    conflicted_files=(${(f)"$(git -C "$repo_dir" diff --name-only --diff-filter=U 2>/dev/null)"})
    [[ ${#conflicted_files[@]} -eq 0 ]] && break

    rad-yellow "Conflicts in ${#conflicted_files[@]} file(s):"
    printf '  %s\n' "${conflicted_files[@]}"
    echo ""

    for file in "${conflicted_files[@]}"; do
      _gwt-resolve-single-conflict "$repo_dir" "$file"
      resolve_result=$?
      if [[ $resolve_result -eq 1 ]]; then
        return 1  # Aborted
      elif [[ $resolve_result -eq 2 ]]; then
        break  # Skipped commit, recheck conflicts
      fi
    done

    # If we skipped (return 2), the rebase already moved on
    [[ $resolve_result -eq 2 ]] && continue

    # Continue the rebase
    if ! git -C "$repo_dir" rebase --continue 2>/dev/null; then
      # More conflicts from next commit, loop again
      continue
    fi
    break
  done
  return 0
}

_gwt-resolve-single-conflict() {
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
        if _gwt-llm-resolve "$repo_dir" "$file"; then
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
        rad-yellow "Skipping this commit entirely (git rebase --skip)"
        git -C "$repo_dir" rebase --skip
        return 2  # Signal to caller that we skipped (don't try rebase --continue)
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

_gwt-llm-resolve() {
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
  response=$(curl -s --max-time 30 "https://api.openai.com/v1/chat/completions" \
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
  if echo "$resolved" | grep -qE "^<<<<<<< |^=======$|^>>>>>>> "; then
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

# gwt - git worktree passthrough
# Usage: gwt <worktree-name> <git-command...>
# Example: gwt feature-branch status
#          gwt feature-branch add .
#          gwt feature-branch commit -m "fix bug"
gwt() {
  if [[ $# -eq 0 ]]; then
    _gwt-list-status
    return 0
  fi

  local wt_name="$1"
  shift

  local wt_dir
  wt_dir="$(_gwt-find-dir "$wt_name")"
  if [[ $? -ne 0 ]] || [[ -z "$wt_dir" ]]; then
    rad-red "Error: Could not find worktree '$wt_name'"
    rad-red "Available worktrees:"
    git worktree list
    return 1
  fi

  local git_cmd="${1:-status}"
  local exit_code

  if [[ $# -eq 0 ]]; then
    # No git command given, show status by default
    git -C "$wt_dir" status
    exit_code=$?
  else
    git -C "$wt_dir" "$@"
    exit_code=$?
  fi

  # If command succeeded and was a state-changing command, show summary + status
  # Skip for read-only commands where auto-status doesn't make sense
  local skip_status=0
  case "$git_cmd" in
    status|diff|log|show|blame|shortlog|describe|ls-files|ls-tree|rev-parse|branch|remote|tag|config)
      skip_status=1
      ;;
  esac

  if [[ $exit_code -eq 0 ]] && [[ $skip_status -eq 0 ]]; then
    echo ""
    _gwt-print-summary "$wt_dir" "$wt_name" "$@"
    git -C "$wt_dir" status
  fi

  return $exit_code
}

# Print summary after git command: ahead/behind + description
_gwt-print-summary() {
  local wt_dir="$1"
  local wt_name="$2"
  shift 2
  local git_cmd="$1"

  local green=$'\e[32m' red=$'\e[31m' reset=$'\e[0m'

  # Get current branch in worktree
  local wt_branch
  wt_branch="$(git -C "$wt_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"

  # Get current branch in cwd for comparison
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  # Calculate ahead/behind relative to current branch
  local ahead behind ahead_behind_str=""
  if [[ -n "$current_branch" ]] && [[ "$wt_branch" != "$current_branch" ]]; then
    ahead=$(git rev-list --count "${current_branch}..${wt_branch}" 2>/dev/null || echo "0")
    behind=$(git rev-list --count "${wt_branch}..${current_branch}" 2>/dev/null || echo "0")

    [[ "$ahead" != "0" ]] && ahead_behind_str="${green}+${ahead}${reset}"
    if [[ "$behind" != "0" ]]; then
      [[ -n "$ahead_behind_str" ]] && ahead_behind_str+="/"
      ahead_behind_str+="${red}-${behind}${reset}"
    fi
    [[ -z "$ahead_behind_str" ]] && ahead_behind_str="${green}up to date${reset}"
  fi

  # Generate description based on command
  local desc
  case "$git_cmd" in
    add)
      desc="Staged files for commit"
      ;;
    commit)
      desc="Created new commit"
      ;;
    reset)
      if [[ "$*" == *"--hard"* ]]; then
        desc="Reset working tree and index to specified state"
      elif [[ "$*" == *"--soft"* ]]; then
        desc="Reset HEAD to specified state, keeping changes staged"
      else
        desc="Unstaged files (kept changes in working tree)"
      fi
      ;;
    checkout)
      if [[ "$2" == "-b" ]]; then
        desc="Created and switched to new branch"
      else
        desc="Restored files or switched context"
      fi
      ;;
    stash)
      if [[ -z "$2" ]] || [[ "$2" == "push" ]]; then
        desc="Stashed changes for later"
      elif [[ "$2" == "pop" ]]; then
        desc="Applied and removed most recent stash"
      elif [[ "$2" == "apply" ]]; then
        desc="Applied stash (kept in stash list)"
      elif [[ "$2" == "drop" ]]; then
        desc="Removed stash entry"
      else
        desc="Modified stash"
      fi
      ;;
    restore)
      desc="Restored file contents"
      ;;
    rm)
      desc="Removed files from working tree and index"
      ;;
    mv)
      desc="Moved or renamed files"
      ;;
    revert)
      desc="Created commit reverting previous changes"
      ;;
    cherry-pick)
      desc="Applied commit(s) from another branch"
      ;;
    merge)
      desc="Merged changes from another branch"
      ;;
    rebase)
      desc="Rebased commits onto new base"
      ;;
    pull)
      desc="Fetched and integrated remote changes"
      ;;
    fetch)
      desc="Downloaded objects and refs from remote"
      ;;
    clean)
      desc="Removed untracked files from working tree"
      ;;
    *)
      desc="Executed git $git_cmd"
      ;;
  esac

  # Print: description + ahead/behind on same line
  if [[ -n "$ahead_behind_str" ]]; then
    rad-yellow "$desc"
    echo "[$wt_branch] vs [$current_branch]: $ahead_behind_str"
  else
    rad-yellow "$desc"
  fi
  echo ""
}

# Show all worktrees with ahead/behind status relative to current branch
# Format matches git-taculous theme: green +N, red -N, green S, red U, yellow ?
_gwt-list-status() {
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [[ -z "$current_branch" ]]; then
    rad-red "Error: Not in a git repository"
    return 1
  fi

  # Colors matching git-taculous
  local green=$'\e[32m' red=$'\e[31m' yellow=$'\e[33m' reset=$'\e[0m'

  echo "Worktrees relative to: ${yellow}${current_branch}${reset}"
  echo ""

  local wt_path wt_branch line
  local ahead behind ahead_behind_str changes_str
  local has_staged has_unstaged has_untracked status_output

  # Parse worktree list and print each result as it's computed
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${match[1]}"
    elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
      wt_branch="${match[1]}"
    elif [[ -z "$line" ]] && [[ -n "$wt_path" ]]; then
      # End of worktree entry, compute and print status
      if [[ -n "$wt_branch" ]]; then
        # Skip if same as current branch
        if [[ "$wt_branch" != "$current_branch" ]]; then
          # Count ahead/behind
          ahead=$(git rev-list --count "${current_branch}..${wt_branch}" 2>/dev/null || echo "?")
          behind=$(git rev-list --count "${wt_branch}..${current_branch}" 2>/dev/null || echo "?")

          # Format ahead/behind like git-taculous
          ahead_behind_str=""
          if [[ "$ahead" != "0" ]]; then
            ahead_behind_str="${green}+${ahead}${reset}"
          fi
          if [[ "$behind" != "0" ]]; then
            [[ -n "$ahead_behind_str" ]] && ahead_behind_str+="/"
            ahead_behind_str+="${red}-${behind}${reset}"
          fi

          # Check for staged/unstaged/untracked changes
          has_staged=""
          has_unstaged=""
          has_untracked=""
          status_output="$(git -C "$wt_path" status --porcelain 2>/dev/null)"
          if [[ -n "$status_output" ]]; then
            # Staged: lines starting with [MADRC] in first column
            echo "$status_output" | grep -qE '^[MADRC]' && has_staged=1
            # Unstaged: lines with [MADRC] in second column (but not ??)
            echo "$status_output" | grep -qE '^.[MADRC]' && has_unstaged=1
            # Untracked: lines starting with ??
            echo "$status_output" | grep -q '^??' && has_untracked=1
          fi

          # Format changes like git-taculous: green S, red U, yellow ?
          changes_str=""
          [[ -n "$has_staged" ]] && changes_str+="${green}S${reset}"
          [[ -n "$has_unstaged" ]] && changes_str+="${red}U${reset}"
          [[ -n "$has_untracked" ]] && changes_str+="${yellow}?${reset}"

          # Combine output
          printf "  %-40s %s %s\n" "${wt_branch}" "${ahead_behind_str:-${green}up to date${reset}}" "${changes_str}"
        fi
      fi
      # Reset for next worktree
      wt_path=""
      wt_branch=""
    fi
  done < <(git worktree list --porcelain 2>/dev/null; echo "")
}

_gwt() {
  _arguments '1:worktree:->wt' '*:git command:->gitcmd'
  case "$state" in
    wt)
      local -a wts
      wts=("${(@f)$(_gwt-list-names)}")
      _describe 'worktree' wts
      ;;
    gitcmd)
      # Provide common git subcommands
      local -a gitcmds
      gitcmds=(
        'status:Show working tree status'
        'diff:Show changes'
        'add:Add file contents to index'
        'commit:Record changes to repository'
        'log:Show commit logs'
        'stash:Stash changes'
        'reset:Reset current HEAD'
        'checkout:Switch branches or restore files'
      )
      _describe 'git command' gitcmds
      ;;
  esac
}

# ============================================================================
# Help command
# ============================================================================

gwt-help() {
  cat <<'EOF'
Git Worktree Commands
=====================

MAIN COMMANDS:
  gwt                    List all worktrees with ahead/behind status
  gwt <wt> <git-cmd>     Run git command in worktree
  wt-push <to> [from]    Push commits to another worktree (rebase)
  wt-pull <from>         Pull commits from another worktree

SHORTHAND ALIASES:
  gwd  <wt> [args]       → gwt <wt> diff [args]
  gwds <wt>              → gwt <wt> diff --stat
  gwa  <wt> [files]      → gwt <wt> add [files or .]
  gwc  <wt> -m "msg"     → gwt <wt> commit -m "msg"
  gwl  <wt>              → gwt <wt> log --oneline -10
  gwst <wt> [args]       → gwt <wt> stash [args]

ZAW (interactive picker):
  Alt+W                  Show worktree picker with actions

EXAMPLES:
  gwt                           # See which worktrees are ahead/behind
  gwt feature-x status          # Check status of feature-x worktree
  gwa feature-x                 # Stage all changes in feature-x
  gwc feature-x -m "fix bug"    # Commit in feature-x
  wt-push feature-x             # Push current commits to feature-x
  wt-pull feature-x             # Pull commits from feature-x here
EOF
}

# ============================================================================
# Workflow aliases - shorthand for common gwt operations
# ============================================================================

# gwd <wt> [args] - show diff for worktree
gwtd() {
  [[ $# -eq 0 ]] && { rad-red "Usage: gwtd <worktree> [diff args...]"; return 1; }
  local wt="$1"; shift
  gwt "$wt" diff "$@"
}

# gwtds <wt> - show diff --stat for worktree
gwtds() {
  [[ $# -eq 0 ]] && { rad-red "Usage: gwtds <worktree>"; return 1; }
  gwt "$1" diff --stat
}

# gwta <wt> [files] - add files in worktree (defaults to .)
gwta() {
  [[ $# -eq 0 ]] && { rad-red "Usage: gwta <worktree> [files...]"; return 1; }
  local wt="$1"; shift
  if [[ $# -eq 0 ]]; then
    gwt "$wt" add .
  else
    gwt "$wt" add "$@"
  fi
}

# gwtc <wt> <args> - commit in worktree
gwtc() {
  [[ $# -lt 2 ]] && { rad-red "Usage: gwtc <worktree> -m \"message\" [commit args...]"; return 1; }
  local wt="$1"; shift
  gwt "$wt" commit "$@"
}

# ============================================================================
# Completion registration
# ============================================================================

# Completion for all worktree aliases - uses same worktree list
_gwt-alias() {
  _arguments '1:worktree:->wt' '*:args:->args'
  case "$state" in
    wt)
      local -a wts
      wts=("${(@f)$(_gwt-list-names)}")
      _describe 'worktree' wts
      ;;
  esac
}

# Completion registration helper for compctl (old system fallback)
_gwt-completion-reply() {
  reply=("${(@f)$(_gwt-list-names)}")
}

# Register with compctl - works immediately during plugin load
# The init hook (rad_git_plugin_init_hook) registers with compdef after compinit
compctl -K _gwt-completion-reply wt-diff wt-push wt-pull gwt gwtd gwtds gwta gwtc gwtl gwtst
