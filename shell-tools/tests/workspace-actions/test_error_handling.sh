#!/usr/bin/env zsh
# Simple test for error handling - run separately to avoid hanging main suite

set +e  # Don't exit on error

cd "/Users/bmf/Library/Mobile Documents/com~apple~CloudDocs/_mine/icode/brandon-fryslie_rad-plugins"

echo "Testing error handling for missing fzf..."

PATH='/usr/bin:/bin'
output=$(source shell-tools/workspace-actions.zsh 2>&1 && workspace-actions 2>&1)
exit_code=$?

echo "Output: $output"
echo "Exit code: $exit_code"

if echo "$output" | grep -q "workspace-actions requires fzf"; then
    echo "✓ PASS: Error message displayed"
    exit 0
else
    echo "✗ FAIL: No error message"
    exit 1
fi
