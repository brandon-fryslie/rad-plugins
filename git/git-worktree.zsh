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

gwt-diff() {
  # input: worktree name
  # output: git -C /worktree/path diff (diff between changes on worktree and latest commit on worktree)

  if [[ $# -eq 0 ]]; then
    rad-red "Usage: gwt-diff <worktree-name> [git diff args...]"
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
gwt-push() {
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
    rad-red "Usage: gwt-push <to-worktree> [from-worktree]"
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
    from_wt_dir="$(_gwt-find-dir "$from_wt_name")"
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

  # Auto-commit uncommitted changes in target worktree
  if [[ -n "$(git -C "$to_wt_dir" status --porcelain)" ]]; then
    rad-yellow "Auto-committing uncommitted changes in '$to_wt_name':"
    git -C "$to_wt_dir" status --short
    local files
    files="$(git -C "$to_wt_dir" status --porcelain | awk '{print $2}' | head -5 | tr '\n' ' ')"
    git -C "$to_wt_dir" add .
    git -C "$to_wt_dir" commit -m "WIP: ${files}"
    rad-green "Auto-committed in '$to_wt_name'"
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

  # Pull with rebase in the target worktree from the source branch
  if ! git -C "$to_wt_dir" pull --rebase . "$from_branch" 2>/dev/null; then
    _gwt-resolve-conflicts "$to_wt_dir" || return 1
  fi

  rad-green "Successfully pushed to '$to_wt_name' ($to_branch)"
}

# pull changes from a wt to current branch
gwt-pull() {
  # input:
  #   1 arg: worktree name (from wt)
  #   2 args: not valid (use gwt-push 2 arg form)
  # result:
  # - fails if any uncommitted changes on to-wt
  # - warns if uncommitted changes on from-wt
  # - designed to be run from main wt of repo but can run from any wt
  # - 1 arg form: use current dir as 'to-wt' and arg as 'from-wt'

  if [[ $# -eq 0 ]]; then
    rad-red "Usage: gwt-pull <worktree-name>"
    rad-red "  Pulls commits from the specified worktree into current branch"
    return 1
  fi

  if [[ $# -gt 1 ]]; then
    rad-red "Error: gwt-pull only accepts 1 argument"
    rad-red "  For 2-arg form, use: gwt-push <from-wt> <to-wt>"
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

  # Auto-commit uncommitted changes in current worktree
  if [[ -n "$(git -C "$to_wt_dir" status --porcelain)" ]]; then
    rad-yellow "Auto-committing uncommitted changes in current worktree:"
    git -C "$to_wt_dir" status --short
    local files
    files="$(git -C "$to_wt_dir" status --porcelain | awk '{print $2}' | head -5 | tr '\n' ' ')"
    git -C "$to_wt_dir" add .
    git -C "$to_wt_dir" commit -m "WIP: ${files}"
    rad-green "Auto-committed"
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

  # Pull with rebase from the local branch
  if ! git -C "$to_wt_dir" pull --rebase . "$from_branch" 2>/dev/null; then
    _gwt-resolve-conflicts "$to_wt_dir" || return 1
  fi

  rad-green "Successfully pulled from '$from_wt_name' ($from_branch)"
}

# Sync commits with a worktree (push then pull)
# Conflicts are auto-resolved:
#   - .agent_planning/*.md: take theirs
#   - Other files: commit with conflict markers for later resolution
gwt-sync() {
  if [[ $# -eq 0 ]]; then
    rad-red "Usage: gwt-sync <worktree>"
    rad-red "  Pushes commits to worktree, then pulls back"
    return 1
  fi

  local wt_name="$1"
  local wt_dir
  wt_dir="$(_gwt-find-dir "$wt_name")"
  if [[ $? -ne 0 ]] || [[ -z "$wt_dir" ]]; then
    rad-red "Error: Could not find worktree '$wt_name'"
    return 1
  fi

  rad-green "=== Syncing with '$wt_name' ==="
  echo ""

  # Pull first - get worktree's commits onto main
  rad-yellow ">>> Pulling from '$wt_name'..."
  if ! gwt-pull "$wt_name"; then
    rad-red "Pull from '$wt_name' failed"
    return 1
  fi

  # Push second - share main's combined commits back to worktree
  rad-yellow ">>> Pushing to '$wt_name'..."
  if ! gwt-push "$wt_name"; then
    rad-red "Push to '$wt_name' failed"
    return 1
  fi

  rad-green "=== Sync with '$wt_name' complete ==="
}

# Save state of all worktrees for undo
# Saves to .git/gwt-sync-state
_gwt-save-state() {
  local git_dir state_file wt_path wt_head line
  git_dir="$(git rev-parse --git-dir 2>/dev/null)"
  state_file="$git_dir/gwt-sync-state"

  # Save timestamp and main HEAD
  echo "# gwt-sync-all state - $(date -Iseconds)" > "$state_file"
  echo "main:$(pwd):$(git rev-parse HEAD)" >> "$state_file"

  # Save each worktree's HEAD
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${match[1]}"
      [[ "$wt_path" == "$(pwd)" ]] && continue
      wt_head="$(git -C "$wt_path" rev-parse HEAD 2>/dev/null)"
      echo "wt:$wt_path:$wt_head" >> "$state_file"
    fi
  done < <(git worktree list --porcelain 2>/dev/null)

  rad-green "Saved state to $state_file"
}

# Restore all worktrees to pre-sync state
gwt-undo-sync() {
  local git_dir state_file
  git_dir="$(git rev-parse --git-dir 2>/dev/null)"
  state_file="$git_dir/gwt-sync-state"

  if [[ ! -f "$state_file" ]]; then
    rad-red "No sync state found. Run gwt-sync-all first."
    return 1
  fi

  rad-yellow "Restoring from: $(head -1 "$state_file")"
  echo ""

  local line type path sha
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    type="${line%%:*}"
    line="${line#*:}"
    path="${line%%:*}"
    sha="${line#*:}"

    if [[ "$type" == "main" ]]; then
      rad-yellow "Restoring main ($(pwd)) to $sha"
      git reset --hard "$sha"
    elif [[ "$type" == "wt" ]]; then
      rad-yellow "Restoring ${path:t} to $sha"
      git -C "$path" reset --hard "$sha"
    fi
  done < "$state_file"

  echo ""
  rad-green "All worktrees restored to pre-sync state"
  rad-yellow "State file kept at $state_file (run again to re-restore if needed)"
}

# Squash all commits on a worktree branch relative to current branch
# Usage: gwt-squash <worktree>
gwt-squash() {
  if [[ $# -eq 0 ]]; then
    rad-red "Usage: gwt-squash <worktree>"
    return 1
  fi

  local wt_name="$1"
  local wt_dir current_branch merge_base commit_count

  wt_dir="$(_gwt-find-dir "$wt_name")"
  if [[ $? -ne 0 ]] || [[ -z "$wt_dir" ]]; then
    rad-red "Error: Could not find worktree '$wt_name'"
    return 1
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD)"
  merge_base="$(git -C "$wt_dir" merge-base HEAD "$current_branch" 2>/dev/null)"

  if [[ -z "$merge_base" ]]; then
    rad-red "Could not find merge base between worktree and $current_branch"
    return 1
  fi

  commit_count="$(git -C "$wt_dir" rev-list --count "$merge_base"..HEAD)"

  if [[ "$commit_count" -le 1 ]]; then
    rad-green "Worktree '$wt_name' has $commit_count commit(s), no squash needed"
    return 0
  fi

  rad-yellow "Squashing $commit_count commits in '$wt_name'..."

  # Get commit messages for the squashed commit
  local messages
  messages="$(git -C "$wt_dir" log --oneline "$merge_base"..HEAD | head -10)"

  # Soft reset to merge base (keeps changes staged)
  git -C "$wt_dir" reset --soft "$merge_base"

  # Commit with summary of squashed commits
  git -C "$wt_dir" commit -m "Squashed $commit_count commits:
$messages"

  rad-green "Squashed $commit_count commits into one in '$wt_name'"
}

# Sync with all worktrees
# Usage: gwt-sync-all [--clean|--auto|--wave|-i|--interactive]
#   --clean       Only sync worktrees with no conflicts
#   --auto        Sync clean + auto-resolvable (planning docs only)
#   --wave        Sync in waves: clean, then auto, then stop for complex
#   -i/--interactive  Full guided workflow with conflict resolution
#   (no flag)     Sync all worktrees (old behavior, may leave conflict markers)
gwt-sync-all() {
  local mode="all"
  case "$1" in
    --clean) mode="clean"; shift ;;
    --auto) mode="auto"; shift ;;
    --wave) mode="wave"; shift ;;
    -i|--interactive) mode="interactive"; shift ;;
  esac

  # Interactive mode is a completely different workflow
  if [[ "$mode" == "interactive" ]]; then
    _gwt-sync-interactive
    return $?
  fi

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ -z "$current_branch" ]]; then
    rad-red "Error: Not in a git repository"
    return 1
  fi

  local -a worktrees wt_paths
  local wt_path wt_branch line

  # Collect all worktrees except current (need both branch name and path)
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${match[1]}"
    elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
      wt_branch="${match[1]}"
    elif [[ -z "$line" ]] && [[ -n "$wt_path" ]]; then
      if [[ -n "$wt_branch" ]] && [[ "$wt_branch" != "$current_branch" ]]; then
        worktrees+=("$wt_branch")
        wt_paths+=("$wt_path")
      fi
      wt_path=""
      wt_branch=""
    fi
  done < <(git worktree list --porcelain 2>/dev/null; echo "")

  if [[ ${#worktrees[@]} -eq 0 ]]; then
    rad-yellow "No other worktrees to sync"
    return 0
  fi

  rad-green "=== Pass 1: Save state for undo ==="
  _gwt-save-state
  echo ""

  rad-green "=== Pass 2: Auto-commit uncommitted changes ==="
  echo ""

  local i wt wt_dir files
  for (( i=1; i<=${#worktrees[@]}; i++ )); do
    wt="${worktrees[$i]}"
    wt_dir="${wt_paths[$i]}"

    if [[ -n "$(git -C "$wt_dir" status --porcelain 2>/dev/null)" ]]; then
      rad-yellow "Uncommitted changes in '$wt':"
      git -C "$wt_dir" status --short

      # Auto-commit with generated message
      files="$(git -C "$wt_dir" status --porcelain | awk '{print $2}' | head -5 | tr '\n' ' ')"
      git -C "$wt_dir" add .
      git -C "$wt_dir" commit -m "WIP: ${files}"
      rad-green "Auto-committed in '$wt'"
      echo ""
    fi
  done

  rad-green "=== Pass 3: Squash worktree commits ==="
  echo ""

  for (( i=1; i<=${#worktrees[@]}; i++ )); do
    wt="${worktrees[$i]}"
    gwt-squash "$wt"
  done
  echo ""

  # If mode requires analysis, categorize worktrees
  local -a clean_wts auto_wts complex_wts
  local -a clean_paths auto_paths complex_paths

  if [[ "$mode" != "all" ]]; then
    rad-green "=== Pass 4: Analyzing conflicts ==="
    echo ""

    # Create temp worktree for analysis
    local temp_dir
    temp_dir="$(mktemp -d)"
    git worktree add --quiet --detach "$temp_dir" HEAD 2>/dev/null

    for (( i=1; i<=${#worktrees[@]}; i++ )); do
      wt="${worktrees[$i]}"
      wt_dir="${wt_paths[$i]}"

      # Reset temp worktree
      git -C "$temp_dir" reset --hard "$current_branch" 2>/dev/null

      # Try merge
      if git -C "$temp_dir" merge --no-commit --no-ff "$wt" 2>/dev/null; then
        clean_wts+=("$wt")
        clean_paths+=("$wt_dir")
        git -C "$temp_dir" merge --abort 2>/dev/null
      else
        # Check if only planning docs
        local conflicted_files planning_only=1
        conflicted_files=(${(f)"$(git -C "$temp_dir" diff --name-only --diff-filter=U 2>/dev/null)"})

        for file in "${conflicted_files[@]}"; do
          if [[ "$file" != .agent_planning/*.md ]]; then
            planning_only=0
            break
          fi
        done

        if [[ $planning_only -eq 1 ]] && [[ ${#conflicted_files[@]} -gt 0 ]]; then
          auto_wts+=("$wt")
          auto_paths+=("$wt_dir")
        else
          complex_wts+=("$wt")
          complex_paths+=("$wt_dir")
        fi
        git -C "$temp_dir" merge --abort 2>/dev/null
      fi
    done

    # Cleanup temp worktree
    git worktree remove --force "$temp_dir" 2>/dev/null
    rm -rf "$temp_dir"

    echo "  Clean:   ${#clean_wts[@]} worktree(s)"
    echo "  Auto:    ${#auto_wts[@]} worktree(s)"
    echo "  Complex: ${#complex_wts[@]} worktree(s)"
    echo ""
  fi

  rad-green "=== Pass 5: Sync worktrees (mode: $mode) ==="
  echo ""

  local -a succeeded failed skipped

  if [[ "$mode" == "all" ]]; then
    # Old behavior - sync everything
    for wt in "${worktrees[@]}"; do
      if gwt-sync "$wt"; then
        succeeded+=("$wt")
      else
        failed+=("$wt")
      fi
      echo ""
    done
  else
    # Sync clean worktrees
    if [[ ${#clean_wts[@]} -gt 0 ]]; then
      rad-yellow ">>> Syncing ${#clean_wts[@]} CLEAN worktree(s)..."
      echo ""
      for wt in "${clean_wts[@]}"; do
        if gwt-sync "$wt"; then
          succeeded+=("$wt")
        else
          failed+=("$wt")
        fi
        echo ""
      done
    fi

    # Sync auto-resolvable worktrees (if mode allows)
    if [[ "$mode" != "clean" ]] && [[ ${#auto_wts[@]} -gt 0 ]]; then
      rad-yellow ">>> Syncing ${#auto_wts[@]} AUTO-RESOLVABLE worktree(s)..."
      echo ""
      for wt in "${auto_wts[@]}"; do
        if gwt-sync "$wt"; then
          succeeded+=("$wt")
        else
          failed+=("$wt")
        fi
        echo ""
      done
    elif [[ "$mode" == "clean" ]] && [[ ${#auto_wts[@]} -gt 0 ]]; then
      skipped+=("${auto_wts[@]}")
    fi

    # Handle complex worktrees based on mode
    if [[ ${#complex_wts[@]} -gt 0 ]]; then
      case "$mode" in
        clean|auto)
          skipped+=("${complex_wts[@]}")
          ;;
        wave)
          rad-yellow ">>> Stopping before ${#complex_wts[@]} COMPLEX worktree(s)"
          rad-yellow "    Resolve conflicts manually, then run again"
          skipped+=("${complex_wts[@]}")
          ;;
      esac
    fi
  fi

  # Summary
  echo ""
  rad-green "=== Sync Summary ==="
  [[ ${#succeeded[@]} -gt 0 ]] && rad-green "Succeeded: ${(j:, :)succeeded}"
  [[ ${#skipped[@]} -gt 0 ]] && rad-yellow "Skipped:   ${(j:, :)skipped}"
  [[ ${#failed[@]} -gt 0 ]] && rad-red "Failed:    ${(j:, :)failed}"

  if [[ ${#failed[@]} -gt 0 ]]; then
    rad-yellow "Run 'gwt-undo-sync' to restore all worktrees to pre-sync state"
    return 1
  fi

  if [[ ${#skipped[@]} -gt 0 ]]; then
    echo ""
    rad-yellow "Some worktrees were skipped. To sync them:"
    rad-yellow "  gwt-sync-all -i  # full interactive workflow"
    rad-yellow "  gwt-sync <wt>    # sync specific worktree"
  fi

  return 0
}

# ============================================================================
# Interactive sync workflow - guided step-by-step
# ============================================================================

_gwt-sync-interactive() {
  local green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m'
  local cyan=$'\e[36m' bold=$'\e[1m' dim=$'\e[2m' reset=$'\e[0m'

  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ -z "$current_branch" ]]; then
    rad-red "Error: Not in a git repository"
    return 1
  fi

  echo ""
  echo "${bold}╔════════════════════════════════════════════════════════════════╗${reset}"
  echo "${bold}║           GWT-SYNC-ALL INTERACTIVE WORKFLOW                   ║${reset}"
  echo "${bold}╚════════════════════════════════════════════════════════════════╝${reset}"
  echo ""
  echo "Current branch: ${cyan}${current_branch}${reset}"
  echo ""

  # =========================================================================
  # Step 1: Collect worktrees
  # =========================================================================
  echo "${bold}STEP 1: Collecting worktrees...${reset}"

  local -a worktrees wt_paths
  local wt_path wt_branch line

  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${match[1]}"
    elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
      wt_branch="${match[1]}"
    elif [[ -z "$line" ]] && [[ -n "$wt_path" ]]; then
      if [[ -n "$wt_branch" ]] && [[ "$wt_branch" != "$current_branch" ]]; then
        worktrees+=("$wt_branch")
        wt_paths+=("$wt_path")
      fi
      wt_path=""
      wt_branch=""
    fi
  done < <(git worktree list --porcelain 2>/dev/null; echo "")

  if [[ ${#worktrees[@]} -eq 0 ]]; then
    rad-yellow "No other worktrees to sync"
    return 0
  fi

  echo "  Found ${#worktrees[@]} worktree(s) to sync"
  echo ""

  # =========================================================================
  # Step 2: Save state
  # =========================================================================
  echo "${bold}STEP 2: Saving state for undo...${reset}"
  _gwt-save-state
  echo ""

  # =========================================================================
  # Step 3: Auto-commit uncommitted changes
  # =========================================================================
  echo "${bold}STEP 3: Checking for uncommitted changes...${reset}"
  echo ""

  local i wt wt_dir files has_uncommitted=0
  for (( i=1; i<=${#worktrees[@]}; i++ )); do
    wt="${worktrees[$i]}"
    wt_dir="${wt_paths[$i]}"

    if [[ -n "$(git -C "$wt_dir" status --porcelain 2>/dev/null)" ]]; then
      has_uncommitted=1
      echo "  ${yellow}$wt${reset} has uncommitted changes:"
      git -C "$wt_dir" status --short | sed 's/^/    /'

      echo ""
      echo -n "  Auto-commit these changes? [Y/n/q] "
      read -r response
      case "$response" in
        [nN])
          echo "  ${yellow}Skipping - uncommitted changes remain${reset}"
          ;;
        [qQ])
          echo "  ${red}Aborted${reset}"
          return 1
          ;;
        *)
          files="$(git -C "$wt_dir" status --porcelain | awk '{print $2}' | head -5 | tr '\n' ' ')"
          git -C "$wt_dir" add .
          git -C "$wt_dir" commit -m "WIP: ${files}"
          echo "  ${green}Auto-committed${reset}"
          ;;
      esac
      echo ""
    fi
  done

  [[ $has_uncommitted -eq 0 ]] && echo "  No uncommitted changes found"
  echo ""

  # =========================================================================
  # Step 4: Squash commits
  # =========================================================================
  echo "${bold}STEP 4: Squashing worktree commits...${reset}"
  echo ""

  for (( i=1; i<=${#worktrees[@]}; i++ )); do
    wt="${worktrees[$i]}"
    gwt-squash "$wt" 2>&1 | sed 's/^/  /'
  done
  echo ""

  # =========================================================================
  # Step 5: Analyze conflicts
  # =========================================================================
  echo "${bold}STEP 5: Analyzing potential conflicts...${reset}"
  echo ""

  local -a clean_wts auto_wts complex_wts
  local -A wt_conflicts  # Store conflict details
  local temp_dir
  temp_dir="$(mktemp -d)"
  git worktree add --quiet --detach "$temp_dir" HEAD 2>/dev/null

  for (( i=1; i<=${#worktrees[@]}; i++ )); do
    wt="${worktrees[$i]}"
    wt_dir="${wt_paths[$i]}"

    git -C "$temp_dir" reset --hard "$current_branch" 2>/dev/null

    if git -C "$temp_dir" merge --no-commit --no-ff "$wt" 2>/dev/null; then
      clean_wts+=("$wt")
      echo "  ${green}✓${reset} $wt - ${green}clean${reset}"
      git -C "$temp_dir" merge --abort 2>/dev/null
    else
      local conflicted_files planning_only=1
      conflicted_files=(${(f)"$(git -C "$temp_dir" diff --name-only --diff-filter=U 2>/dev/null)"})

      local conflict_list=""
      for file in "${conflicted_files[@]}"; do
        conflict_list+="$file\n"
        if [[ "$file" != .agent_planning/*.md ]]; then
          planning_only=0
        fi
      done

      wt_conflicts[$wt]="$conflict_list"

      if [[ $planning_only -eq 1 ]] && [[ ${#conflicted_files[@]} -gt 0 ]]; then
        auto_wts+=("$wt")
        echo "  ${yellow}~${reset} $wt - ${yellow}auto-resolvable${reset} (${#conflicted_files[@]} planning doc(s))"
      else
        complex_wts+=("$wt")
        echo "  ${red}✗${reset} $wt - ${red}complex${reset} (${#conflicted_files[@]} file(s))"
      fi

      git -C "$temp_dir" merge --abort 2>/dev/null
    fi
  done

  git worktree remove --force "$temp_dir" 2>/dev/null
  rm -rf "$temp_dir"

  echo ""
  echo "  ─────────────────────────────────"
  echo "  Clean:   ${green}${#clean_wts[@]}${reset} (will sync without issues)"
  echo "  Auto:    ${yellow}${#auto_wts[@]}${reset} (planning docs only, auto-resolved)"
  echo "  Complex: ${red}${#complex_wts[@]}${reset} (may need manual resolution)"
  echo ""

  echo -n "Continue with sync? [Y/n] "
  read -r response
  [[ "$response" == [nN]* ]] && { echo "Aborted"; return 1; }
  echo ""

  # =========================================================================
  # Step 6: Sync each worktree
  # =========================================================================
  echo "${bold}STEP 6: Syncing worktrees...${reset}"
  echo ""

  local -a succeeded failed
  local total=$((${#clean_wts[@]} + ${#auto_wts[@]} + ${#complex_wts[@]}))
  local current=0

  # Helper function for syncing with progress
  _sync_one() {
    local wt="$1"
    local category="$2"
    ((current++))

    echo "────────────────────────────────────────────────────────────────"
    echo "[${current}/${total}] ${bold}$wt${reset} (${category})"
    echo "────────────────────────────────────────────────────────────────"
    echo ""

    if gwt-sync "$wt"; then
      # Check for conflict markers in working tree
      local markers
      markers=$(git grep -l -E '^<{7} |^={7}$|^>{7} ' 2>/dev/null || true)

      if [[ -n "$markers" ]]; then
        echo ""
        echo "${red}${bold}CONFLICT MARKERS DETECTED${reset}"
        echo "The following files have unresolved conflicts:"
        echo "$markers" | sed 's/^/  /'
        echo ""

        _gwt_resolve_loop "$wt"
        return $?
      else
        succeeded+=("$wt")
        echo "${green}✓ $wt synced successfully${reset}"
      fi
    else
      failed+=("$wt")
      echo "${red}✗ $wt sync failed${reset}"
    fi
    echo ""
  }

  # Sync clean worktrees
  for wt in "${clean_wts[@]}"; do
    _sync_one "$wt" "${green}clean${reset}"
  done

  # Sync auto-resolvable worktrees
  for wt in "${auto_wts[@]}"; do
    _sync_one "$wt" "${yellow}auto${reset}"
  done

  # Sync complex worktrees with extra guidance
  for wt in "${complex_wts[@]}"; do
    echo "────────────────────────────────────────────────────────────────"
    echo "[${current}/${total}] ${bold}$wt${reset} (${red}complex${reset})"
    echo "────────────────────────────────────────────────────────────────"
    echo ""
    echo "${yellow}This worktree has potential conflicts in:${reset}"
    echo -e "${wt_conflicts[$wt]}" | sed 's/^/  /'
    echo ""
    echo -n "Sync this worktree? [Y/n/s(kip)/q(uit)] "
    read -r response

    case "$response" in
      [nN]|[sS])
        echo "Skipped"
        ((current++))
        continue
        ;;
      [qQ])
        echo "Stopping here. Remaining worktrees not synced."
        break
        ;;
    esac

    ((current++))

    if gwt-sync "$wt"; then
      local markers
      markers=$(git grep -l -E '^<{7} |^={7}$|^>{7} ' 2>/dev/null || true)

      if [[ -n "$markers" ]]; then
        echo ""
        echo "${red}${bold}CONFLICT MARKERS DETECTED${reset}"
        echo "The following files have unresolved conflicts:"
        echo "$markers" | sed 's/^/  /'
        echo ""

        _gwt_resolve_loop "$wt"
        [[ $? -ne 0 ]] && break
      else
        succeeded+=("$wt")
        echo "${green}✓ $wt synced successfully${reset}"
      fi
    else
      failed+=("$wt")
      echo "${red}✗ $wt sync failed${reset}"
    fi
    echo ""
  done

  # =========================================================================
  # Summary
  # =========================================================================
  echo ""
  echo "${bold}╔════════════════════════════════════════════════════════════════╗${reset}"
  echo "${bold}║                        SYNC COMPLETE                           ║${reset}"
  echo "${bold}╚════════════════════════════════════════════════════════════════╝${reset}"
  echo ""

  [[ ${#succeeded[@]} -gt 0 ]] && echo "${green}Succeeded:${reset} ${(j:, :)succeeded}"
  [[ ${#failed[@]} -gt 0 ]] && echo "${red}Failed:${reset} ${(j:, :)failed}"

  local remaining=$((total - ${#succeeded[@]} - ${#failed[@]}))
  [[ $remaining -gt 0 ]] && echo "${yellow}Remaining:${reset} $remaining worktree(s)"

  echo ""

  if [[ ${#failed[@]} -gt 0 ]]; then
    rad-yellow "Some syncs failed. Run 'gwt-undo-sync' to restore all worktrees."
    return 1
  fi

  return 0
}

# Resolution loop - waits for user to fix conflicts
_gwt_resolve_loop() {
  local wt="$1"
  local green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' reset=$'\e[0m'

  while true; do
    echo "${yellow}Options:${reset}"
    echo "  [r] Resolve now - open files, fix conflicts, then return here"
    echo "  [c] Check again - verify conflicts are resolved"
    echo "  [d] Show diff   - see current state of conflicted files"
    echo "  [a] Abort       - stop sync, rollback with gwt-undo-sync"
    echo "  [f] Force continue - commit with markers (not recommended)"
    echo ""
    echo -n "Choice: "
    read -r choice

    case "$choice" in
      [rR])
        echo ""
        echo "Resolve the conflicts in your editor, then come back and press 'c' to check."
        echo "${dim}Tip: Files with conflicts are listed above${reset}"
        echo ""
        ;;
      [cC])
        local markers
        markers=$(git grep -l -E '^<{7} |^={7}$|^>{7} ' 2>/dev/null || true)

        if [[ -z "$markers" ]]; then
          echo "${green}All conflicts resolved!${reset}"
          echo ""
          echo -n "Commit the resolution? [Y/n] "
          read -r commit_response

          if [[ "$commit_response" != [nN]* ]]; then
            git add .
            git commit -m "Resolved merge conflicts from $wt"
            echo "${green}Committed resolution${reset}"
          fi

          succeeded+=("$wt")
          return 0
        else
          echo "${red}Conflicts still exist in:${reset}"
          echo "$markers" | sed 's/^/  /'
          echo ""
        fi
        ;;
      [dD])
        echo ""
        git diff --stat
        echo ""
        ;;
      [aA])
        echo "${yellow}Aborting. Run 'gwt-undo-sync' to restore all worktrees.${reset}"
        return 1
        ;;
      [fF])
        echo "${red}WARNING: Committing with conflict markers!${reset}"
        echo -n "Are you sure? [y/N] "
        read -r force_response
        if [[ "$force_response" == [yY]* ]]; then
          git add .
          git commit -m "WIP: Merge from $wt (has conflict markers)"
          succeeded+=("$wt")
          return 0
        fi
        ;;
      *)
        echo "Unknown option: $choice"
        ;;
    esac
  done
}

# Try to auto-merge a conflicted file using kdiff3
# Always applies non-conflicting changes to the file
# Returns 0 if fully resolved, 1 if still has conflicts, 2 if kdiff3 not installed
_gwt-try-auto-merge() {
  local repo_dir="$1"
  local file="$2"

  # Require kdiff3 - no fallback
  if ! command -v kdiff3 &>/dev/null; then
    rad-red "Error: kdiff3 is required for auto-merge but not installed"
    rad-yellow "Install with: brew install kdiff3"
    return 2
  fi

  local base_file ours_file theirs_file merged_file

  # Create temp files for 3-way merge
  base_file="$(mktemp)"
  ours_file="$(mktemp)"
  theirs_file="$(mktemp)"
  merged_file="$(mktemp)"

  # Extract the three versions
  # :1: = base, :2: = ours, :3: = theirs
  git -C "$repo_dir" show ":1:$file" > "$base_file" 2>/dev/null || echo "" > "$base_file"
  git -C "$repo_dir" show ":2:$file" > "$ours_file" 2>/dev/null
  git -C "$repo_dir" show ":3:$file" > "$theirs_file" 2>/dev/null

  local resolved=1

  # Run kdiff3 auto-merge (may exit non-zero if conflicts remain)
  kdiff3 --auto --cs "AutoSaveOnMergeExit=true" \
     "$base_file" "$ours_file" "$theirs_file" -o "$merged_file" 2>/dev/null

  # Always use the output if it exists - it has non-conflicting changes applied
  if [[ -s "$merged_file" ]]; then
    cp "$merged_file" "$repo_dir/$file"
    # Check if fully resolved (no conflict markers)
    if ! grep -qE '^<{7} |^={7}$|^>{7} ' "$merged_file" 2>/dev/null; then
      resolved=0
    fi
  fi

  # Cleanup temp files
  rm -f "$base_file" "$ours_file" "$theirs_file" "$merged_file"

  return $resolved
}

# Resolve remaining conflict markers in a file by taking "theirs" side
# Use after kdiff3 auto-merge to resolve just the conflicting sections
_gwt-take-theirs-in-conflicts() {
  local file="$1"

  # Use awk to process conflict markers:
  # - Skip lines from <<<<<<< to =======
  # - Keep lines from after ======= to before >>>>>>>
  # - Skip the >>>>>>> line
  awk '
    /^<{7} / { in_ours=1; next }
    /^={7}$/ { in_ours=0; in_theirs=1; next }
    /^>{7} / { in_theirs=0; next }
    !in_ours { print }
  ' "$file" > "${file}.resolved"

  mv "${file}.resolved" "$file"
}

# Auto-resolve conflicts during sync:
# 1. Try kdiff3 auto-merge - applies all non-conflicting changes
# 2. For remaining conflicts in .agent_planning/*.md: take theirs for just the conflict sections
# 3. For remaining conflicts in other files: ABORT - do not commit conflict markers
_gwt-resolve-conflicts() {
  local repo_dir="$1"
  local conflicted_files file merge_result
  local has_unresolved=0

  while true; do
    conflicted_files=(${(f)"$(git -C "$repo_dir" diff --name-only --diff-filter=U 2>/dev/null)"})
    [[ ${#conflicted_files[@]} -eq 0 ]] && break

    rad-yellow "Auto-resolving ${#conflicted_files[@]} conflict(s):"
    has_unresolved=0

    for file in "${conflicted_files[@]}"; do
      # Try kdiff3 auto-merge - always applies non-conflicting changes
      _gwt-try-auto-merge "$repo_dir" "$file"
      merge_result=$?

      if [[ $merge_result -eq 2 ]]; then
        # kdiff3 not installed - fatal error
        git -C "$repo_dir" rebase --abort 2>/dev/null
        return 1
      elif [[ $merge_result -eq 0 ]]; then
        # Fully resolved by kdiff3
        git -C "$repo_dir" add "$file"
        rad-green "  $file -> auto-merged (kdiff3)"
      elif [[ "$file" == .agent_planning/*.md ]]; then
        # Planning doc with remaining conflicts:
        # kdiff3 already applied non-conflicting changes, now resolve just the conflict sections
        _gwt-take-theirs-in-conflicts "$repo_dir/$file"
        git -C "$repo_dir" add "$file"
        rad-green "  $file -> auto-merged + took theirs for conflicts (planning doc)"
      else
        # Other file with remaining conflicts - DO NOT COMMIT
        has_unresolved=1
        rad-red "  $file -> UNRESOLVED (needs manual resolution)"
      fi
    done

    echo ""

    # If any files have unresolved conflicts, abort the rebase
    if [[ $has_unresolved -eq 1 ]]; then
      rad-red "Aborting: unresolved conflicts detected"
      rad-yellow "The conflicted files are in your working directory."
      rad-yellow "Resolve them manually, then run gwt-sync again."
      git -C "$repo_dir" rebase --abort 2>/dev/null
      return 1
    fi

    # Continue the rebase
    # Use GIT_EDITOR=true to skip commit message editing for conflict commits
    if ! GIT_EDITOR=true git -C "$repo_dir" rebase --continue 2>/dev/null; then
      # More conflicts from next commit, loop again
      continue
    fi
    break
  done
  return 0
}

# ============================================================================
# Analyze conflicts before syncing
# ============================================================================

# Analyze what would happen if we synced each worktree
# Shows: clean (no conflicts), auto (planning docs only), complex (needs manual)
gwt-analyze() {
  local current_branch temp_dir
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  if [[ -z "$current_branch" ]]; then
    rad-red "Error: Not in a git repository"
    return 1
  fi

  # Create a temp worktree for safe merge testing
  temp_dir="$(mktemp -d)"
  trap "git worktree remove --force '$temp_dir' 2>/dev/null; rm -rf '$temp_dir'" EXIT

  rad-yellow "Creating temp worktree for analysis..."
  if ! git worktree add --quiet --detach "$temp_dir" HEAD 2>/dev/null; then
    rad-red "Failed to create temp worktree"
    return 1
  fi

  local -a clean_wts auto_wts complex_wts
  local -A conflict_details
  local wt_path wt_branch wt_head line

  echo ""
  rad-green "Analyzing merge conflicts for each worktree..."
  echo ""

  # Analyze each worktree
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${match[1]}"
    elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
      wt_branch="${match[1]}"
    elif [[ -z "$line" ]] && [[ -n "$wt_path" ]]; then
      # Skip current worktree and detached heads
      if [[ "$wt_path" != "$(pwd)" ]] && [[ -n "$wt_branch" ]] && [[ "$wt_branch" != "$current_branch" ]]; then
        local wt_name="${wt_path:t}"

        # Reset temp worktree to current branch
        git -C "$temp_dir" reset --hard "$current_branch" 2>/dev/null

        # Try to merge the worktree branch
        local merge_output
        if merge_output=$(git -C "$temp_dir" merge --no-commit --no-ff "$wt_branch" 2>&1); then
          # Clean merge - no conflicts
          clean_wts+=("$wt_name")
          git -C "$temp_dir" merge --abort 2>/dev/null
        else
          # Has conflicts - analyze which files
          local conflicted_files planning_only=1
          conflicted_files=(${(f)"$(git -C "$temp_dir" diff --name-only --diff-filter=U 2>/dev/null)"})

          local file_list=""
          for file in "${conflicted_files[@]}"; do
            if [[ "$file" != .agent_planning/*.md ]]; then
              planning_only=0
            fi
            file_list+="    $file\n"
          done

          if [[ $planning_only -eq 1 ]] && [[ ${#conflicted_files[@]} -gt 0 ]]; then
            auto_wts+=("$wt_name")
            conflict_details[$wt_name]="${#conflicted_files[@]} planning doc(s)"
          else
            complex_wts+=("$wt_name")
            conflict_details[$wt_name]="${#conflicted_files[@]} file(s):\n$file_list"
          fi

          git -C "$temp_dir" merge --abort 2>/dev/null
        fi
      fi
      wt_path=""
      wt_branch=""
    fi
  done < <(git worktree list --porcelain 2>/dev/null; echo "")

  # Display results
  local green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' dim=$'\e[2m' reset=$'\e[0m'

  echo "=== Analysis Results ==="
  echo ""

  if [[ ${#clean_wts[@]} -gt 0 ]]; then
    echo "${green}CLEAN (no conflicts) - safe to sync:${reset}"
    for wt in "${clean_wts[@]}"; do
      echo "  $wt"
    done
    echo ""
  fi

  if [[ ${#auto_wts[@]} -gt 0 ]]; then
    echo "${yellow}AUTO-RESOLVABLE (planning docs only):${reset}"
    for wt in "${auto_wts[@]}"; do
      echo "  $wt ${dim}(${conflict_details[$wt]})${reset}"
    done
    echo ""
  fi

  if [[ ${#complex_wts[@]} -gt 0 ]]; then
    echo "${red}COMPLEX (needs manual resolution):${reset}"
    for wt in "${complex_wts[@]}"; do
      echo "  $wt"
      echo -e "${dim}${conflict_details[$wt]}${reset}"
    done
    echo ""
  fi

  # Summary
  echo "=== Summary ==="
  echo "  Clean:    ${#clean_wts[@]}"
  echo "  Auto:     ${#auto_wts[@]}"
  echo "  Complex:  ${#complex_wts[@]}"
  echo ""

  if [[ ${#complex_wts[@]} -gt 0 ]]; then
    rad-yellow "Recommended: Run 'gwt-sync-all --wave' to sync in order of complexity"
  elif [[ ${#auto_wts[@]} -gt 0 ]]; then
    rad-green "All conflicts are auto-resolvable. Run 'gwt-sync-all --auto'"
  else
    rad-green "All worktrees are clean! Run 'gwt-sync-all'"
  fi
}

# Run a git command across multiple worktrees
# Usage: gwt-all [filter] <git-command...>
# Filters:
#   --all, -a       All worktrees (default)
#   --dirty, -d     Only worktrees with uncommitted changes
#   --ahead         Only worktrees with commits ahead of current branch
#   --behind        Only worktrees with commits behind current branch
#   --diverged      Only worktrees that are both ahead and behind
#   --detached      Only worktrees in detached HEAD state
# Examples:
#   gwt-all status              # Run git status in all worktrees
#   gwt-all --dirty add .       # Add all files in dirty worktrees
#   gwt-all --ahead log -1      # Show last commit in worktrees ahead
gwt-all() {
  local filter="all"
  local current_branch wt_path wt_head wt_branch line ahead behind
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  # Parse filter flag
  case "$1" in
    --all|-a)
      filter="all"
      shift
      ;;
    --dirty|-d)
      filter="dirty"
      shift
      ;;
    --ahead)
      filter="ahead"
      shift
      ;;
    --behind)
      filter="behind"
      shift
      ;;
    --diverged)
      filter="diverged"
      shift
      ;;
    --detached)
      filter="detached"
      shift
      ;;
  esac

  if [[ $# -eq 0 ]]; then
    rad-red "Usage: gwt-all [--all|--dirty|--ahead|--behind|--diverged|--detached] <git-command...>"
    return 1
  fi

  local -a matching_wts matching_paths
  local green=$'\e[32m' yellow=$'\e[33m' dim=$'\e[2m' reset=$'\e[0m'

  # Collect matching worktrees
  while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${match[1]}"

      # Skip current worktree
      [[ "$wt_path" == "$(pwd)" ]] && continue

      wt_branch="$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
      wt_head="$(git -C "$wt_path" rev-parse HEAD 2>/dev/null)"

      local dominated=0
      case "$filter" in
        all)
          dominated=1
          ;;
        dirty)
          [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null)" ]] && dominated=1
          ;;
        ahead)
          ahead=$(git rev-list --count "${current_branch}..${wt_head}" 2>/dev/null || echo "0")
          [[ "$ahead" -gt 0 ]] && dominated=1
          ;;
        behind)
          behind=$(git rev-list --count "${wt_head}..${current_branch}" 2>/dev/null || echo "0")
          [[ "$behind" -gt 0 ]] && dominated=1
          ;;
        diverged)
          ahead=$(git rev-list --count "${current_branch}..${wt_head}" 2>/dev/null || echo "0")
          behind=$(git rev-list --count "${wt_head}..${current_branch}" 2>/dev/null || echo "0")
          [[ "$ahead" -gt 0 && "$behind" -gt 0 ]] && dominated=1
          ;;
        detached)
          [[ "$wt_branch" == "HEAD" ]] && dominated=1
          ;;
      esac

      if [[ $dominated -eq 1 ]]; then
        matching_wts+=("${wt_path:t}")
        matching_paths+=("$wt_path")
      fi
    fi
  done < <(git worktree list --porcelain 2>/dev/null)

  if [[ ${#matching_wts[@]} -eq 0 ]]; then
    rad-yellow "No worktrees match filter: $filter"
    return 0
  fi

  rad-green "Running 'git $*' in ${#matching_wts[@]} worktree(s):"
  echo ""

  local i name wt_dir
  for (( i=1; i<=${#matching_wts[@]}; i++ )); do
    name="${matching_wts[$i]}"
    wt_dir="${matching_paths[$i]}"

    echo "${yellow}=== ${name} ===${reset}"
    git -C "$wt_dir" "$@"
    echo ""
  done
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

# Show all worktrees with ahead/behind status
_gwt-list-status() {
  local current_branch
  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  local green=$'\e[32m' red=$'\e[31m' yellow=$'\e[33m' dim=$'\e[2m' reset=$'\e[0m'

  echo "Worktrees relative to: ${yellow}${current_branch}${reset}"
  echo ""

  # Declare loop variables outside the loop to avoid zsh's local re-declaration printing
  local wt_path wt_branch wt_head ahead behind status_str is_detached visible_name

  git worktree list --porcelain | while IFS= read -r line; do
    if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
      wt_path="${match[1]}"
      wt_branch="$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
      # Get actual commit SHA for reliable comparison (especially for detached HEAD)
      wt_head="$(git -C "$wt_path" rev-parse HEAD 2>/dev/null)"

      if [[ "$wt_branch" == "HEAD" || -z "$wt_branch" ]]; then
        # Detached HEAD - use directory name instead
        visible_name="${wt_path:t}"
        is_detached=1
      else
        visible_name="$wt_branch"
        is_detached=0
      fi

      [[ "$wt_path" == "$(pwd)" ]] && continue

      # Use commit SHA for comparison to handle detached HEAD correctly
      ahead=$(git rev-list --count "${current_branch}..${wt_head}" 2>/dev/null || echo "?")
      behind=$(git rev-list --count "${wt_head}..${current_branch}" 2>/dev/null || echo "?")

      status_str=""
      [[ "$ahead" != "0" && "$ahead" != "?" ]] && status_str="${green}+${ahead}${reset}"
      if [[ "$behind" != "0" && "$behind" != "?" ]]; then
        [[ -n "$status_str" ]] && status_str+="/"
        status_str+="${red}-${behind}${reset}"
      fi
      [[ -z "$status_str" ]] && status_str="${green}up to date${reset}"

      if [[ $is_detached -eq 1 ]]; then
        printf "  %-40s %s ${dim}(detached)${reset}\n" "$visible_name" "$status_str"
      else
        printf "  %-40s %s\n" "$visible_name" "$status_str"
      fi
    fi
  done
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
  gwt                       List all worktrees with ahead/behind status
  gwt <wt> <git-cmd>        Run git command in worktree
  gwt-analyze               Analyze conflicts before syncing (shows clean/auto/complex)
  gwt-push <to> [from]      Push commits to another worktree (rebase)
  gwt-pull <from>           Pull commits from another worktree
  gwt-sync <wt>             Sync with worktree (pull then push)
  gwt-sync-all [mode]       Sync with all worktrees (see modes below)
  gwt-undo-sync             Restore all worktrees to pre-sync state
  gwt-squash <wt>           Squash all worktree commits into one
  gwt-all [filter] <cmd>    Run git command across multiple worktrees

GWT-SYNC-ALL MODES:
  (no flag)                 Sync all worktrees (may leave conflict markers)
  --clean                   Only sync worktrees with no conflicts
  --auto                    Sync clean + auto-resolvable (planning docs only)
  --wave                    Sync clean, then auto, then STOP for complex
  -i, --interactive         RECOMMENDED: Full guided workflow with prompts

GWT-ALL FILTERS:
  --all, -a                 All worktrees (default)
  --dirty, -d               Only worktrees with uncommitted changes
  --ahead                   Only worktrees ahead of current branch
  --behind                  Only worktrees behind current branch
  --diverged                Only worktrees both ahead and behind
  --detached                Only worktrees in detached HEAD state

SHORTHAND ALIASES:
  gwtd  <wt> [args]         → gwt <wt> diff [args]
  gwtds <wt>                → gwt <wt> diff --stat
  gwta  <wt> [files]        → gwt <wt> add [files or .]
  gwtc  <wt> -m "msg"       → gwt <wt> commit -m "msg"

ZAW (interactive picker):
  Ctrl+Alt+W                Show worktree picker with actions

CONFLICT RESOLUTION:
  Conflicts are auto-resolved using kdiff3:
  - Non-conflicting changes from both sides are always applied
  - .agent_planning/*.md: remaining conflicts → take theirs
  - Other files: remaining conflicts → keep markers for manual resolution

RECOMMENDED WORKFLOW:
  gwt-sync-all -i                   # Full guided interactive workflow
                                    # Walks you through every step:
                                    # - Saves state for undo
                                    # - Auto-commits uncommitted changes
                                    # - Squashes worktree commits
                                    # - Analyzes conflicts
                                    # - Syncs each worktree
                                    # - Pauses for manual conflict resolution
                                    # - Commits resolutions
                                    # - Shows final summary

EXAMPLES:
  gwt                             # See which worktrees are ahead/behind
  gwt-analyze                     # Preview conflicts before syncing
  gwt-sync-all -i                 # RECOMMENDED: Full guided workflow
  gwt feature-x status            # Check status of feature-x worktree
  gwt-all status                  # Status of all worktrees
  gwt-all --dirty add .           # Stage all changes in dirty worktrees
  gwt-sync-all --wave             # Sync clean + auto, stop at complex
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
compctl -K _gwt-completion-reply gwt-diff gwt-push gwt-pull gwt-sync gwt gwtd gwtds gwta gwtc gwtl gwtst
