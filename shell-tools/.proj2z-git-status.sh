#!/usr/bin/env zsh
# Standalone git status script for proj2
# Args: project_path
# Outputs: p10k-styled git status string
# PRIORITY: SUT flags first (most important for knowing if there are uncommitted changes)

local project_path="$1"

[[ ! -d "$project_path/.git" ]] && exit 0

cd "$project_path" 2>/dev/null || exit 0

# ANSI color codes matching p10k theme
local reset=$'\033[0m'
local bold=$'\033[1m'
local ul=$'\033[4m'
local meta=$'\033[38;5;246m'
local clean=$'\033[38;5;76m'
local staged=$'\033[38;5;40m'
local unstaged=$'\033[38;5;160m'
local ahead_c=$'\033[38;5;39m'
local behind_c=$'\033[38;5;178m'
local remote_c=$'\033[38;5;28m'
local conflict=$'\033[38;5;196m'

# PRIORITY 1: Get branch name (fast, local only)
local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[[ -z $branch ]] && exit 0

# PRIORITY 2: Single git status call for SUT + ahead/behind (this is the slow part)
# Using --porcelain=v1 -b gives us everything in one call
local status_output=$(git status --porcelain=v1 -b 2>/dev/null)
local header_line="${status_output%%$'\n'*}"
local file_lines="${status_output#*$'\n'}"
[[ "$status_output" == "$header_line" ]] && file_lines=""  # No files changed

# Parse SUT from file lines (MOST IMPORTANT - do this before anything else)
local num_staged=0 num_unstaged=0 num_untracked=0 num_conflicted=0
if [[ -n "$file_lines" ]]; then
  num_staged=$(echo "$file_lines" | grep -c '^[MADRC]' 2>/dev/null) || num_staged=0
  num_unstaged=$(echo "$file_lines" | grep -c '^.[MD]' 2>/dev/null) || num_unstaged=0
  num_untracked=$(echo "$file_lines" | grep -c '^??' 2>/dev/null) || num_untracked=0
  num_conflicted=$(echo "$file_lines" | grep -c '^UU\|^AA\|^DD' 2>/dev/null) || num_conflicted=0
fi
num_staged=${num_staged//[^0-9]/}; num_staged=${num_staged:-0}
num_unstaged=${num_unstaged//[^0-9]/}; num_unstaged=${num_unstaged:-0}
num_untracked=${num_untracked//[^0-9]/}; num_untracked=${num_untracked:-0}
num_conflicted=${num_conflicted//[^0-9]/}; num_conflicted=${num_conflicted:-0}

# Parse ahead/behind from header line: ## branch...origin/branch [ahead 1, behind 2]
local ahead=0 behind=0
if [[ $header_line =~ '\[ahead ([0-9]+)' ]]; then
  ahead=${match[1]:-0}
  ahead=${ahead//[^0-9]/}; ahead=${ahead:-0}
fi
if [[ $header_line =~ 'behind ([0-9]+)' ]]; then
  behind=${match[1]:-0}
  behind=${behind//[^0-9]/}; behind=${behind:-0}
fi

# PRIORITY 3: Get remote info (fast, local config read)
local remote_name=$(git config --get branch.$branch.remote 2>/dev/null)
local remote_branch=""
# Extract from header if available: ## branch...origin/branch
if [[ $header_line =~ '\.\.\.([^] \[]+)' ]]; then
  remote_branch="${match[1]#*/}"
fi

# PRIORITY 4 (LOWEST): Time since last commit (can be slow on network mounts)
local time_ago=""
local last_commit_epoch=$(git log -1 --format='%ct' 2>/dev/null)
last_commit_epoch=${last_commit_epoch//[^0-9]/}
if [[ -n $last_commit_epoch && $last_commit_epoch -gt 0 ]]; then
  local now=$(date +%s)
  local diff=$((now - last_commit_epoch))
  (( diff < 0 )) && diff=0
  if (( diff < 3600 )); then
    time_ago="$((diff / 60))m"
  elif (( diff < 86400 )); then
    time_ago="$((diff / 3600))h"
  elif (( diff < 604800 )); then
    time_ago="$((diff / 86400))d"
  elif (( diff < 2592000 )); then
    time_ago="$((diff / 604800))w"
  else
    time_ago="$((diff / 2592000))mo"
  fi
fi

# Build status string
local res=""

# Ahead/behind
(( behind > 0 )) && res+="${bold}${behind_c}-${ul}${behind}${reset} "
(( ahead > 0 )) && res+="${bold}${ahead_c}+${ul}${ahead}${reset} "

# Branch name (truncate if long)
local display_branch=$branch
(( ${#branch} > 20 )) && display_branch="${branch:0:8}…${branch: -8}"
res+="${clean}${display_branch}${reset}"

# Remote tracking with SUT flags
res+=" ${meta}[${remote_c}"
if [[ -n $remote_branch ]]; then
  res+="${remote_name}/${remote_branch}"
else
  res+="${meta}local"
fi
# SUT flags (always show if present, even without remote)
if (( num_staged > 0 || num_unstaged > 0 || num_untracked > 0 )); then
  res+=" ${bold}"
  (( num_staged > 0 )) && res+="${staged}S"
  (( num_unstaged > 0 )) && res+="${unstaged}U"
  (( num_untracked > 0 )) && res+="${meta}T"
  res+="${reset}"
fi
res+="${meta}]${reset}"

# Conflicts
(( num_conflicted > 0 )) && res+=" ${conflict}~${num_conflicted}${reset}"

# Time since last commit
[[ -n $time_ago ]] && res+=" ${meta}${time_ago}${reset}"

echo "$res"
