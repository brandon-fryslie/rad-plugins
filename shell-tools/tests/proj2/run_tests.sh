#!/usr/bin/env zsh
# Comprehensive test runner for proj2 tests
# Runs both pytest/ptytest tests and legacy shell tests

set -euo pipefail

SCRIPT_DIR="${${(%):-%x}:A:h}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "proj2 (p2z) Comprehensive Test Suite"
echo "========================================="
echo ""

# Track overall exit code
EXIT_CODE=0

# Parse command line arguments
RUN_PYTEST=true
RUN_SHELL_TESTS=true
PYTEST_ARGS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fast)
            PYTEST_ARGS="$PYTEST_ARGS --fast"
            shift
            ;;
        --ci)
            PYTEST_ARGS="$PYTEST_ARGS --ci"
            shift
            ;;
        --pytest-only)
            RUN_SHELL_TESTS=false
            shift
            ;;
        --shell-only)
            RUN_PYTEST=false
            shift
            ;;
        -k|--keyword)
            PYTEST_ARGS="$PYTEST_ARGS -k $2"
            shift 2
            ;;
        -m|--marker)
            PYTEST_ARGS="$PYTEST_ARGS -m $2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--fast] [--ci] [--pytest-only] [--shell-only] [-k KEYWORD] [-m MARKER]"
            exit 1
            ;;
    esac
done

# Run pytest/ptytest tests
if [[ $RUN_PYTEST == true ]]; then
    echo -e "${BLUE}Running pytest/ptytest tests...${NC}"
    echo ""

    if chmod +x "${SCRIPT_DIR}/run_tests.py" 2>/dev/null; then
        if python3 "${SCRIPT_DIR}/run_tests.py" $=PYTEST_ARGS; then
            echo -e "${GREEN}✓ Pytest tests passed!${NC}"
        else
            echo -e "${RED}✗ Pytest tests failed!${NC}"
            EXIT_CODE=1
        fi
    else
        echo -e "${YELLOW}⚠ Warning: Could not make run_tests.py executable${NC}"
        echo -e "${YELLOW}  Try: chmod +x ${SCRIPT_DIR}/run_tests.py${NC}"
    fi

    echo ""
    echo "----------------------------------------"
    echo ""
fi

# Run legacy shell tests
if [[ $RUN_SHELL_TESTS == true ]]; then
    echo -e "${BLUE}Running legacy shell tests...${NC}"
    echo ""

    # Run the existing shell test
    if [[ -f "${SCRIPT_DIR}/test_preview_args.sh" ]]; then
        chmod +x "${SCRIPT_DIR}/test_preview_args.sh"
        if "${SCRIPT_DIR}/test_preview_args.sh"; then
            echo -e "${GREEN}✓ Shell tests passed!${NC}"
        else
            echo -e "${RED}✗ Shell tests failed!${NC}"
            EXIT_CODE=1
        fi
    else
        echo -e "${YELLOW}⚠ Warning: test_preview_args.sh not found${NC}"
    fi

    echo ""
    echo "----------------------------------------"
    echo ""
fi

# Final summary
echo "========================================="
echo "Final Results"
echo "========================================="

if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
else
    echo -e "${RED}Some tests failed!${NC}"
fi

echo "========================================="

exit $EXIT_CODE
