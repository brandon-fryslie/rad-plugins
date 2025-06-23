#!/usr/bin/env bash
set -eu

outer_dev=""
nested_dev=""

cleanup() {
  [[ -n "$nested_dev" ]] && hdiutil detach "$nested_dev" -quiet || true
  [[ -n "$outer_dev" ]] && hdiutil detach "$outer_dev" -quiet || true
}

error_handler() {
  local code=$?
  local cmd="${BASH_COMMAND:-unknown}"
  [[ "$cmd" != "exit" && $code -ne 0 ]] && {
    echo "ERROR: Command failed → $cmd"
    echo "Exit code: $code"
    echo "Line: $1"
  }
  cleanup
  exit $code
}

trap 'error_handler $LINENO' ERR
trap cleanup EXIT

input=${1:-}
[[ -z "$input" ]] && { echo "ERROR: Must provide .dmg or directory"; exit 1; }

if [[ -d "$input" ]]; then
  dmg_path=$(find "$input" -type f -name '*.dmg' ! -name '_*' ! -path '*/__MACOSX/*' | head -n 1)
elif [[ -f "$input" && "$input" == *.dmg ]]; then
  dmg_path="$input"
else
  echo "ERROR: Not a dmg or folder containing one"
  exit 1
fi

[[ -z "${dmg_path:-}" ]] && { echo "ERROR: No .dmg found in $input"; exit 1; }

before_info=$(hdiutil info)
hdiutil attach "$dmg_path" -nobrowse -quiet
after_info=$(hdiutil info)

outer_mount_line=$(diff <(echo "$before_info") <(echo "$after_info") | grep '^> image-path' -A10 | grep '/Volumes/' | head -n 1)
outer_vol=$(echo "$outer_mount_line" | awk '{print $NF}')
[[ -d "$outer_vol" ]] || { echo "ERROR: Could not determine mount point for $dmg_path"; exit 1; }

outer_dev=$(echo "$after_info" | grep -B1 "$outer_vol" | grep '^/dev/' | awk '{print $1}')
[[ -n "$outer_dev" ]] || { echo "ERROR: Could not determine device for $dmg_path"; exit 1; }

nested_dmg=$(find "$outer_vol" -type f -name '*.dmg' ! -name '_*' | head -n 1)
mount_vol="$outer_vol"

if [[ -n "${nested_dmg:-}" ]]; then
  before_nested=$(hdiutil info)
  hdiutil attach "$nested_dmg" -nobrowse -quiet
  after_nested=$(hdiutil info)

  nested_mount_line=$(diff <(echo "$before_nested") <(echo "$after_nested") | grep '^> image-path' -A10 | grep '/Volumes/' | head -n 1)
  mount_vol=$(echo "$nested_mount_line" | awk '{print $NF}')
  [[ -d "$mount_vol" ]] || { echo "ERROR: Could not determine nested mount"; exit 1; }

  nested_dev=$(echo "$after_nested" | grep -B1 "$mount_vol" | grep '^/dev/' | awk '{print $1}')
  [[ -n "$nested_dev" ]] || { echo "ERROR: Could not get nested device"; exit 1; }
fi

installed=false
shopt -s nullglob
for app in "$mount_vol"/*.app; do
  [[ "$(basename "$app")" == _* ]] && continue
  sudo cp -R "$app" /Applications
  sudo xattr -rd com.apple.quarantine "/Applications/$(basename "$app")"
  installed=true
done

if [[ "$installed" == false ]]; then
  pkg=$(find "$mount_vol" -type f -name '*.pkg' ! -name '_*' | head -n 1)
  if [[ -n "${pkg:-}" ]]; then
    sudo installer -pkg "$pkg" -target /
    installed=true
  fi
fi

if [[ "$installed" == false ]]; then
  echo "ERROR: No .app or .pkg found in $mount_vol"
  exit 1
fi