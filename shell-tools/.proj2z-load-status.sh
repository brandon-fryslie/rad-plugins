#!/usr/bin/env zsh
# Load git status for all projects and output filtered list
# Args: query project_data_file script_dir

query="$1"
project_data_file="$2"
script_dir="$3"
git_status_script="${script_dir}/.proj2-git-status.sh"

# Suppress job control
setopt LOCAL_OPTIONS NO_NOTIFY NO_MONITOR

# Create temp dir for status output
local status_dir=$(mktemp -d)
trap "rm -rf '$status_dir'" EXIT

# Pure zsh timeout using background + sleep + kill
_timeout_run() {
  local timeout=$1 outfile=$2
  shift 2
  "$@" > "$outfile" &
  local cmd_pid=$!
  ( sleep $timeout; kill $cmd_pid 2>/dev/null ) &
  local killer_pid=$!
  wait $cmd_pid 2>/dev/null
  kill $killer_pid 2>/dev/null
  wait $killer_pid 2>/dev/null
}

# Read project data and launch parallel git status jobs
local -a all_paths all_displays all_mtimes all_active
local i=0
while IFS=$'\t' read -r proj_path proj_display proj_mtime proj_active; do
  [[ -z "$proj_path" ]] && continue
  i=$((i + 1))
  all_paths+=("$proj_path")
  all_displays+=("$proj_display")
  all_mtimes+=("$proj_mtime")
  all_active+=("$proj_active")

  if [[ -d "$proj_path/.git" ]]; then
    _timeout_run 0.5 "${status_dir}/${i}" zsh "$git_status_script" "$proj_path" &
  else
    echo "" > "${status_dir}/${i}" &
  fi
done < "$project_data_file"
wait

# Build display strings with git status
local -a active_with_mtime inactive_with_mtime
for (( j=1; j <= i; j++ )); do
  local display="${all_displays[$j]}"
  local mtime="${all_mtimes[$j]}"
  local is_active="${all_active[$j]}"
  local git_status=""

  [[ -f "${status_dir}/${j}" ]] && git_status=$(<"${status_dir}/${j}")

  local display_full
  if [[ -n "$git_status" ]]; then
    display_full="${display}  ${git_status}"
  else
    display_full="${display}"
  fi

  if [[ "$is_active" == "1" ]]; then
    active_with_mtime+=("${mtime}|● ${display_full}")
  else
    inactive_with_mtime+=("${mtime}|${display_full}")
  fi
done

# Sort by mtime (descending)
local -a sorted_active sorted_inactive
for entry in ${(On)active_with_mtime}; do
  sorted_active+=("${entry#*|}")
done
for entry in ${(On)inactive_with_mtime}; do
  sorted_inactive+=("${entry#*|}")
done

# Strip ANSI for matching
_strip_ansi() {
  echo "$1" | sed $'s/\x1b\\[[0-9;]*m//g'
}

_matches_query() {
  local item="$1" q="$2"
  [[ -z "$q" ]] && return 0
  local clean=$(_strip_ansi "$item")
  [[ "${clean:l}" == *"${q:l}"* ]]
}

# Output filtered results (active first, then inactive)
for item in "${sorted_active[@]}"; do
  [[ -z "$item" ]] && continue
  _matches_query "$item" "$query" && echo "$item"
done

for item in "${sorted_inactive[@]}"; do
  [[ -z "$item" ]] && continue
  _matches_query "$item" "$query" && echo "$item"
done
