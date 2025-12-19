#!/usr/bin/env zsh
# Test runner for proj2 tests

set -euo pipefail

SCRIPT_DIR="${${(%):-%x}:A:h}"

echo "Running proj2 functional tests..."
echo ""

# Make test script executable
chmod +x "${SCRIPT_DIR}/test_preview_args.sh"

# Run the test script
"${SCRIPT_DIR}/test_preview_args.sh"

exit_code=$?

if [[ ${exit_code} -eq 0 ]]; then
    echo ""
    echo "✓ All proj2 tests passed!"
else
    echo ""
    echo "✗ Some proj2 tests failed!"
fi

exit ${exit_code}
