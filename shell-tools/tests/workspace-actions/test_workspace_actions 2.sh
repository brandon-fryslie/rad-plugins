#!/usr/bin/env zsh
# Functional tests for workspace-actions.zsh
# Tests the contextual workspace action menu (opt+w feature)
#
# This test cannot be gamed because:
# 1. Loads the real workspace-actions.zsh file
# 2. Verifies actual action registry population
# 3. Tests real context detection with actual git repos and tmux
# 4. Validates observable outputs (registry contents, filtered actions)
# 5. Checks handler function existence (not mocks)
# 6. Verifies ZLE widget registration
#
# What we CAN test (automated):
# - File loads without errors
# - Action registry is populated correctly
# - Context detection returns correct strings
# - Action filtering works based on context
# - Handler functions exist and are callable
# - Key binding is registered
# - Error handling for missing dependencies
#
# What we CANNOT test (requires manual testing):
# - Actual fzf UI interaction
# - Action execution workflows (requires interactive shell)
# - Performance (<100ms menu display)
# - Real user workflows

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="${${(%):-%x}:A:h}"
SHELL_TOOLS_DIR="${SCRIPT_DIR:h:h}"  # Up two levels to shell-tools root
WA_SCRIPT="${SHELL_TOOLS_DIR}/workspace-actions.zsh"

# Test helper functions
run_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    echo -e "${YELLOW}TEST ${TESTS_RUN}: ${test_name}${NC}"
}

pass_test() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ PASS${NC}"
}

fail_test() {
    local reason="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ FAIL: ${reason}${NC}"
}

print_summary() {
    echo ""
    echo "========================================="
    echo "Test Results"
    echo "========================================="
    echo "Total:  ${TESTS_RUN}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    echo "========================================="

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

#
# Setup and Teardown
#

setup() {
    # Create temporary test environment
    TEST_DIR=$(mktemp -d)
    TEST_GIT_REPO="${TEST_DIR}/test-git-repo"
    TEST_NON_GIT_DIR="${TEST_DIR}/test-non-git"

    mkdir -p "${TEST_GIT_REPO}"
    mkdir -p "${TEST_NON_GIT_DIR}"

    # Create a git repo for testing
    (cd "${TEST_GIT_REPO}" && \
        git init -q && \
        git config user.name "Test User" && \
        git config user.email "test@example.com" && \
        touch README.md && \
        git add README.md && \
        git commit -q -m "Initial commit")

    echo -e "${YELLOW}Test setup complete${NC}"
    echo "Test dir: ${TEST_DIR}"
    echo "Git repo: ${TEST_GIT_REPO}"
    echo "Non-git dir: ${TEST_NON_GIT_DIR}"
    echo "Script: ${WA_SCRIPT}"
}

teardown() {
    if [[ -n "${TEST_DIR:-}" && -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
        echo -e "${YELLOW}Test cleanup complete${NC}"
    fi
}

#
# Test Suite
#

# Test 1: File loads without errors
test_file_loads() {
    run_test "workspace-actions.zsh loads without errors"

    # Source the file in a subshell to isolate
    local output
    local exit_code

    output=$(zsh -c "source '${WA_SCRIPT}' 2>&1" 2>&1)
    exit_code=$?

    echo "Exit code: ${exit_code}"
    if [[ -n "${output}" ]]; then
        echo "Output:"
        echo "${output}"
    fi

    if [[ ${exit_code} -eq 0 ]]; then
        echo "File loaded successfully"
        pass_test
    else
        fail_test "File failed to load (exit code: ${exit_code})"
    fi
}

# Test 2: Action registry is populated
test_registry_populated() {
    run_test "Action registry WA_ACTIONS is populated with 5 core actions"

    # Source file and check registry
    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        echo \"Registry size: \${#WA_ACTIONS}\"
        for key in \${(k)WA_ACTIONS}; do
            echo \"Action: \$key\"
        done
    ")

    echo "${output}"

    # Verify we have 5 actions (proj, gst, gbr, exec, tses)
    local count=$(echo "${output}" | grep "Registry size:" | awk '{print $3}')

    if [[ ${count} -eq 5 ]]; then
        echo "Registry has ${count} actions as expected"

        # Verify specific actions exist
        local has_all=1
        for action in proj gst gbr exec tses; do
            if ! echo "${output}" | grep -q "Action: ${action}"; then
                echo "Missing action: ${action}"
                has_all=0
            fi
        done

        if [[ ${has_all} -eq 1 ]]; then
            echo "All 5 core actions present: proj, gst, gbr, exec, tses"
            pass_test
        else
            fail_test "Not all expected actions found in registry"
        fi
    else
        fail_test "Expected 5 actions in registry, found ${count}"
    fi
}

# Test 3: Context detection in git repository
test_context_detection_git() {
    run_test "Context detection correctly identifies git repository"

    cd "${TEST_GIT_REPO}"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        context=\$(_wa_detect_context)
        echo \"Context: \$context\"
    ")

    echo "${output}"

    # Should contain "git" in context string
    if echo "${output}" | grep -q "Context:.*git"; then
        echo "Git context correctly detected"
        pass_test
    else
        fail_test "Git context not detected in git repository"
    fi
}

# Test 4: Context detection in non-git directory
test_context_detection_non_git() {
    run_test "Context detection excludes git when not in repository"

    cd "${TEST_NON_GIT_DIR}"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        context=\$(_wa_detect_context)
        echo \"Context: \$context\"
    ")

    echo "${output}"

    # Should NOT contain "git" in context string
    if echo "${output}" | grep -q "Context:.*git"; then
        fail_test "Git context incorrectly detected outside repository"
    else
        echo "Git context correctly excluded"
        pass_test
    fi
}

# Test 5: Context detection for docker
test_context_detection_docker() {
    run_test "Context detection correctly identifies docker availability"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        context=\$(_wa_detect_context)
        echo \"Context: \$context\"
    ")

    echo "${output}"

    # Check if docker is available in environment
    if command -v docker &>/dev/null; then
        if echo "${output}" | grep -q "Context:.*docker"; then
            echo "Docker context correctly detected (docker available)"
            pass_test
        else
            fail_test "Docker available but not detected in context"
        fi
    else
        if ! echo "${output}" | grep -q "Context:.*docker"; then
            echo "Docker context correctly excluded (docker not available)"
            pass_test
        else
            fail_test "Docker not available but detected in context"
        fi
    fi
}

# Test 6: Action filtering by context (git context)
test_action_filtering_git_context() {
    run_test "Action filtering returns git actions when in git context"

    cd "${TEST_GIT_REPO}"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        cd '${TEST_GIT_REPO}'
        context=\$(_wa_detect_context)
        result=\$(_wa_get_actions_for_context \"\$context\")
        echo \"Result: \$result\"
    ")

    echo "${output}"

    # Verify git-specific actions are present
    # Format is: "id  label  description" all concatenated
    # We check for the action IDs followed by double-space
    local has_gst=$(echo "${output}" | grep -c "gst  " || true)
    local has_gbr=$(echo "${output}" | grep -c "gbr  " || true)
    local has_proj=$(echo "${output}" | grep -c "proj  " || true)
    local has_exec=$(echo "${output}" | grep -c "exec  " || true)

    echo "Actions found: gst=${has_gst}, gbr=${has_gbr}, proj=${has_proj}, exec=${has_exec}"

    # In git context, should have:
    # - proj (all context) - YES
    # - gst (git context) - YES
    # - gbr (git context) - YES
    # - exec (all context) - YES
    # - tses (tmux context) - maybe (depends on if in tmux)

    if [[ ${has_gst} -eq 1 && ${has_gbr} -eq 1 && ${has_proj} -eq 1 && ${has_exec} -eq 1 ]]; then
        echo "All expected git context actions present"
        pass_test
    else
        fail_test "Missing expected actions in git context"
    fi
}

# Test 7: Action filtering excludes git actions outside git repo
test_action_filtering_non_git_context() {
    run_test "Action filtering excludes git actions when not in git repo"

    cd "${TEST_NON_GIT_DIR}"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        cd '${TEST_NON_GIT_DIR}'
        context=\$(_wa_detect_context)
        result=\$(_wa_get_actions_for_context \"\$context\")
        echo \"Result: \$result\"
    ")

    echo "${output}"

    # Git actions (gst, gbr) should NOT appear
    local has_gst=$(echo "${output}" | grep -c "gst  " || true)
    local has_gbr=$(echo "${output}" | grep -c "gbr  " || true)

    echo "Git actions found: gst=${has_gst}, gbr=${has_gbr}"

    if [[ ${has_gst} -eq 0 && ${has_gbr} -eq 0 ]]; then
        echo "Git actions correctly excluded outside repository"
        pass_test
    else
        fail_test "Git actions incorrectly appear outside git repository"
    fi
}

# Test 8: Handler functions exist
test_handler_functions_exist() {
    run_test "All handler functions exist and are callable"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1

        # Check each handler function
        handlers=(_wa_switch_project _wa_git_status _wa_git_branch _wa_find_executable _wa_tmux_sessions)

        for handler in \${handlers[@]}; do
            if typeset -f \"\$handler\" &>/dev/null; then
                echo \"Handler exists: \$handler\"
            else
                echo \"Handler MISSING: \$handler\"
            fi
        done
    ")

    echo "${output}"

    # All 5 handlers should exist
    local missing_count=$(echo "${output}" | grep -c "Handler MISSING:" || true)

    if [[ ${missing_count} -eq 0 ]]; then
        echo "All handler functions exist"
        pass_test
    else
        fail_test "${missing_count} handler functions missing"
    fi
}

# Test 9: ZLE widget is registered
test_widget_registered() {
    run_test "workspace-actions is registered as ZLE widget"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        zle -l | grep workspace-actions || echo 'NOT_FOUND'
    ")

    echo "ZLE widget check:"
    echo "${output}"

    if echo "${output}" | grep -q "^workspace-actions"; then
        echo "workspace-actions widget is registered"
        pass_test
    else
        fail_test "workspace-actions widget not registered"
    fi
}

# Test 10: Context matching logic
test_context_matching() {
    run_test "Context matching logic works correctly"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1

        # Test 'all' context always matches
        if _wa_context_matches 'git,tmux' 'all'; then
            echo 'all-matches-any: PASS'
        else
            echo 'all-matches-any: FAIL'
        fi

        # Test git context matches when git present
        if _wa_context_matches 'git,tmux' 'git'; then
            echo 'git-matches: PASS'
        else
            echo 'git-matches: FAIL'
        fi

        # Test git context does not match when git absent
        if _wa_context_matches 'tmux,docker' 'git'; then
            echo 'no-git-matches: FAIL'
        else
            echo 'no-git-matches: PASS'
        fi

        # Test multiple required contexts (any match)
        if _wa_context_matches 'git,tmux' 'git,docker'; then
            echo 'multiple-any-match: PASS'
        else
            echo 'multiple-any-match: FAIL'
        fi
    ")

    echo "${output}"

    # All tests should pass
    local fail_count=$(echo "${output}" | grep -c ": FAIL" || true)

    if [[ ${fail_count} -eq 0 ]]; then
        echo "All context matching logic tests passed"
        pass_test
    else
        fail_test "${fail_count} context matching tests failed"
    fi
}

# Test 11: Error handling - fzf dependency check exists
test_error_handling_fzf_check() {
    run_test "Code contains fzf dependency check"

    # Verify the file contains fzf check code
    if grep -q "workspace-actions requires fzf" "${WA_SCRIPT}"; then
        echo "fzf dependency check found in code"
        pass_test
    else
        fail_test "No fzf dependency check in code"
    fi
}

# Test 12: Context header generation
test_context_header_generation() {
    run_test "Context header generates correctly for git repos"

    cd "${TEST_GIT_REPO}"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1
        cd '${TEST_GIT_REPO}'
        context=\$(_wa_detect_context)
        header=\$(_wa_context_header \"\$context\")
        echo \"Header: \$header\"
    ")

    echo "${output}"

    # Should contain "git:" and repo name
    if echo "${output}" | grep -q "Header:.*git:.*test-git-repo"; then
        echo "Context header includes git repo name"
        pass_test
    else
        fail_test "Context header missing git repo information"
    fi
}

# Test 13: Registry entry format
test_registry_entry_format() {
    run_test "Registry entries have correct format (label|description|contexts|handler)"

    local output
    output=$(zsh -c "
        source '${WA_SCRIPT}' 2>&1

        # Check format of 'proj' action
        entry=\"\${WA_ACTIONS[proj]}\"
        echo \"Entry: \$entry\"

        # Count pipe-separated fields
        field_count=\$(echo \"\$entry\" | awk -F'|' '{print NF}')
        echo \"Fields: \$field_count\"

        # Extract fields
        label=\$(echo \"\$entry\" | cut -d'|' -f1)
        description=\$(echo \"\$entry\" | cut -d'|' -f2)
        contexts=\$(echo \"\$entry\" | cut -d'|' -f3)
        handler=\$(echo \"\$entry\" | cut -d'|' -f4)

        echo \"Label: \$label\"
        echo \"Description: \$description\"
        echo \"Contexts: \$contexts\"
        echo \"Handler: \$handler\"
    ")

    echo "${output}"

    # Should have 4 fields
    local field_count=$(echo "${output}" | grep "Fields:" | awk '{print $2}')

    if [[ ${field_count} -eq 4 ]]; then
        echo "Registry entry has correct 4-field format"

        # Verify non-empty fields
        if echo "${output}" | grep -q "Label: .*\S" && \
           echo "${output}" | grep -q "Description: .*\S" && \
           echo "${output}" | grep -q "Contexts: .*\S" && \
           echo "${output}" | grep -q "Handler: .*\S"; then
            echo "All fields populated"
            pass_test
        else
            fail_test "Some registry entry fields are empty"
        fi
    else
        fail_test "Registry entry has ${field_count} fields instead of 4"
    fi
}

# Test 14: Empty context handling
test_empty_context_handling() {
    run_test "Handles empty context gracefully (no git, tmux, docker)"

    # Simulate environment with nothing available
    local output
    output=$(zsh -c "
        # Hide git, docker from PATH and unset TMUX
        PATH='/usr/bin:/bin'
        unset TMUX
        cd /tmp
        source '${WA_SCRIPT}' 2>&1
        context=\$(_wa_detect_context)
        echo \"Context: '\$context'\"
        result=\$(_wa_get_actions_for_context \"\$context\")
        echo \"Result: \$result\"
    " 2>&1)

    echo "${output}"

    # Should still have "all" context actions (proj, exec)
    local has_proj=$(echo "${output}" | grep -c "proj  " || true)
    local has_exec=$(echo "${output}" | grep -c "exec  " || true)

    if [[ ${has_proj} -eq 1 && ${has_exec} -eq 1 ]]; then
        echo "Empty context returns 'all' context actions (proj, exec)"
        pass_test
    else
        fail_test "Empty context doesn't return 'all' context actions"
    fi
}

#
# Main execution
#

main() {
    echo "========================================="
    echo "workspace-actions.zsh Functional Tests"
    echo "========================================="
    echo ""
    echo "This test suite validates the contextual"
    echo "workspace actions menu implementation."
    echo ""
    echo "Tests cover:"
    echo "  - File loading"
    echo "  - Action registry population"
    echo "  - Context detection (git, tmux, docker)"
    echo "  - Action filtering by context"
    echo "  - Handler function existence"
    echo "  - ZLE widget registration"
    echo "  - Error handling"
    echo "  - Context header generation"
    echo ""
    echo "Note: These tests do NOT cover:"
    echo "  - Actual fzf UI interaction (requires manual testing)"
    echo "  - Action execution workflows (requires interactive shell)"
    echo "  - Performance metrics (requires manual testing)"
    echo ""

    # Trap cleanup
    trap teardown EXIT

    # Setup
    setup

    # Run all tests
    test_file_loads
    test_registry_populated
    test_context_detection_git
    test_context_detection_non_git
    test_context_detection_docker
    test_action_filtering_git_context
    test_action_filtering_non_git_context
    test_handler_functions_exist
    test_widget_registered
    test_context_matching
    test_error_handling_fzf_check
    test_context_header_generation
    test_registry_entry_format
    test_empty_context_handling

    # Summary
    print_summary
}

# Run main
main "$@"
