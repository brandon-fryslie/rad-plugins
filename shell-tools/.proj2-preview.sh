#!/usr/bin/env zsh
# Preview script for proj2 - shows project info, tmux session, and git status

# Debug logging
exec 2>>/tmp/proj2-preview-debug.log
echo "=== Preview called at $(date) ===" >&2
echo "All args: $@" >&2
echo "Arg count: $#" >&2

project_display="$1"
shift
proj_dirs=("$@")

echo "project_display: $project_display" >&2
echo "proj_dirs: ${proj_dirs[@]}" >&2

# Remove the ● icon if present
project_display="${project_display#● }"

# Strip ANSI codes first (use sed for reliable escape sequence handling)
project_display_clean=$(echo "$project_display" | sed $'s/\x1b\\[[0-9;]*m//g')

# Extract just the project path (before the double-space where git status starts)
project_path_part="${project_display_clean%%  *}"
project_name="${project_path_part##*/}"

echo "After processing - project_name: $project_name" >&2

# Find the actual project path
for base_dir in "${proj_dirs[@]}"; do
  echo "Checking base_dir: $base_dir" >&2
  test_path="${base_dir}/${project_name}"
  echo "test_path: $test_path" >&2
  echo "Exists: $([[ -d "$test_path" ]] && echo yes || echo no)" >&2
  if [[ -d "$test_path" ]]; then
    echo "📁 Path: $test_path"
    echo ""

    # Check for tmux session
    if command -v tmux &>/dev/null && tmux has-session -t "$project_name" 2>/dev/null; then
      session_created=$(tmux display-message -p -t "$project_name" '#{session_created}')
      current_time=$(date +%s)
      session_age=$((current_time - session_created))

      # Convert to human readable
      days=$((session_age / 86400))
      hours=$(((session_age % 86400) / 3600))
      mins=$(((session_age % 3600) / 60))

      echo "🖥️  Tmux Session: $project_name"
      if [ $days -gt 0 ]; then
        echo "   Alive for: ${days}d ${hours}h ${mins}m"
      elif [ $hours -gt 0 ]; then
        echo "   Alive for: ${hours}h ${mins}m"
      else
        echo "   Alive for: ${mins}m"
      fi
      echo ""
    fi

    # Git status (styled to match p10k)
    if [[ -d "$test_path/.git" ]]; then
      cd "$test_path"

      # ANSI 256-color codes matching p10k
      local reset=$'\033[0m'
      local bold=$'\033[1m'
      local underline=$'\033[4m'
      local meta=$'\033[38;5;246m'      # grey
      local clean=$'\033[38;5;76m'      # green
      local staged=$'\033[38;5;40m'     # bright green
      local unstaged=$'\033[38;5;160m'  # red
      local vcs_ahead=$'\033[38;5;39m'  # cyan
      local vcs_behind=$'\033[38;5;178m' # yellow
      local vcs_remote=$'\033[38;5;28m' # dark green
      local conflicted=$'\033[38;5;196m' # bright red
      local modified=$'\033[38;5;178m'  # yellow

      # Gather git info
      local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      local remote_name=$(git config --get branch.$branch.remote 2>/dev/null)
      local remote_branch=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null)
      remote_branch=${remote_branch#*/}  # Strip remote name prefix

      local ahead=$(git rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
      local behind=$(git rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)

      local num_staged=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
      local num_unstaged=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
      local num_untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
      local num_conflicted=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')
      local num_stashes=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
      local action=$(git status 2>/dev/null | head -1 | grep -oE '(rebas|merg|cherry|revert|bisect)ing' || true)

      # Build the status line matching p10k format
      local res=""

      # Commits ahead/behind (shown first)
      if [[ $behind -gt 0 ]]; then
        res+="${bold}${vcs_behind}-${underline}${behind}${reset}${meta}"
      fi
      if [[ $behind -gt 0 && $ahead -gt 0 ]]; then
        res+=" "
      fi
      if [[ $ahead -gt 0 ]]; then
        res+="${bold}${vcs_ahead}+${underline}${ahead}${reset}${meta}"
      fi
      [[ $ahead -gt 0 || $behind -gt 0 ]] && res+=" "

      # Branch name (green)
      if [[ -n $branch ]]; then
        # Truncate long branch names: first 12 … last 12
        if [[ ${#branch} -gt 32 ]]; then
          branch="${branch:0:12}…${branch: -12}"
        fi
        res+="${clean}${branch}${reset}"
      fi

      # Remote tracking info in brackets [remote/branch SU]
      res+=" ${meta}[${vcs_remote}"
      if [[ -n $remote_branch ]]; then
        res+="${remote_name}/${remote_branch}"
        # Staged/Unstaged/Untracked indicators
        if [[ $num_staged -gt 0 || $num_unstaged -gt 0 || $num_untracked -gt 0 ]]; then
          res+=" ${bold}"
          [[ $num_staged -gt 0 ]] && res+="${staged}S"
          [[ $num_unstaged -gt 0 ]] && res+="${unstaged}U"
          [[ $num_untracked -gt 0 ]] && res+="${meta}T"
          res+="${reset}"
        fi
      else
        res+="${meta}(none)"
      fi
      res+="${meta}]${reset}"

      # Merge conflicts
      [[ $num_conflicted -gt 0 ]] && res+=" ${conflicted}~${num_conflicted}${reset}"

      # Stashes
      [[ $num_stashes -gt 0 ]] && res+=" ${meta}(${num_stashes} stashed)${reset}"

      # Action (merge, rebase, etc.)
      [[ -n $action ]] && res+=" ${conflicted}${action}${reset}"

      echo "📊 ${res}"
      echo ""

      # Last commit info (additional context not in p10k)
      local last_commit_time=$(git log -1 --format='%ar' 2>/dev/null)
      local last_commit_msg=$(git log -1 --format='%s' 2>/dev/null | head -c 60)
      if [[ -n $last_commit_time ]]; then
        echo "${meta}Last commit:${reset} $last_commit_time"
        echo "${meta}\"${last_commit_msg}\"${reset}"
        echo ""
      fi

      # Remote URL
      local remote_url=$(git config --get remote.origin.url 2>/dev/null)
      if [[ -n $remote_url ]]; then
        # Convert git@ to https for display
        if [[ $remote_url == git@* ]]; then
          remote_url=${remote_url#git@}
          remote_url=${remote_url/://}
          remote_url="https://${remote_url%.git}"
        fi
        echo "${meta}Remote:${reset} $remote_url"
        echo ""
      fi
    fi

    break
  fi
done
