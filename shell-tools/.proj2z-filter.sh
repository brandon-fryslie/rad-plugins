#!/usr/bin/env zsh
# Filter script for proj2 - filters projects while keeping active sessions at top
# Args: query active_file inactive_file

query="$1"
active_file="$2"
inactive_file="$3"

# Read active and inactive projects from temp files
local -a active_projects inactive_projects filtered_active filtered_inactive

if [[ -f "$active_file" ]]; then
  active_projects=("${(@f)$(<"$active_file")}")
fi

if [[ -f "$inactive_file" ]]; then
  inactive_projects=("${(@f)$(<"$inactive_file")}")
fi

# Strip ANSI escape codes for matching purposes
_strip_ansi() {
  echo "$1" | sed $'s/\x1b\\[[0-9;]*m//g'
}

# Filter function - case-insensitive substring match (strips ANSI for comparison)
_matches_query() {
  local item="$1"
  local q="$2"

  # Empty query matches everything
  [[ -z "$q" ]] && return 0

  # Strip ANSI codes for matching
  local clean_item=$(_strip_ansi "$item")

  # Case-insensitive match
  [[ "${clean_item:l}" == *"${q:l}"* ]]
}

# Filter active projects
for item in "${active_projects[@]}"; do
  [[ -z "$item" ]] && continue
  if _matches_query "$item" "$query"; then
    filtered_active+=("$item")
  fi
done

# Filter inactive projects
for item in "${inactive_projects[@]}"; do
  [[ -z "$item" ]] && continue
  if _matches_query "$item" "$query"; then
    filtered_inactive+=("$item")
  fi
done

# Output: active first, then inactive
for item in "${filtered_active[@]}"; do
  echo "$item"
done

for item in "${filtered_inactive[@]}"; do
  echo "$item"
done
