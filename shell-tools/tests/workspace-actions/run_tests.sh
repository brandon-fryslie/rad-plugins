#!/usr/bin/env zsh
# Test runner for workspace-actions tests

set -euo pipefail

SCRIPT_DIR="${${(%):-%x}:A:h}"

echo "Running workspace-actions functional tests..."
echo ""

# Make test script executable
chmod +x "${SCRIPT_DIR}/test_workspace_actions.sh"

# Run the test script
"${SCRIPT_DIR}/test_workspace_actions.sh"

exit_code=$?

if [[ ${exit_code} -eq 0 ]]; then
    echo ""
    echo "✓ All workspace-actions tests passed!"
else
    echo ""
    echo "✗ Some workspace-actions tests failed!"
fi

exit ${exit_code}
