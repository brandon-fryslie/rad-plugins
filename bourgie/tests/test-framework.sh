#!/usr/bin/env zsh

# Bourgie Theme Testing Framework
# Provides utilities for testing zsh functions and configurations

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Test counters
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Test state
CURRENT_TEST=""
TEST_FAILED=false
SETUP_FUNCTIONS=()
TEARDOWN_FUNCTIONS=()

# Test output capture
TEST_OUTPUT=""
TEST_STDERR=""

# Initialize test framework
function test_init() {
    TEST_COUNT=0
    PASS_COUNT=0
    FAIL_COUNT=0
    SKIP_COUNT=0
    
    # Create temporary test directory
    export TEST_TEMP_DIR=$(mktemp -d -t bourgie-test-XXXXXX)
    export TEST_HOME="$TEST_TEMP_DIR/home"
    export TEST_CONFIG_DIR="$TEST_TEMP_DIR/config"
    
    mkdir -p "$TEST_HOME" "$TEST_CONFIG_DIR"
    
    echo -e "${CYAN}🧪 Bourgie Theme Test Framework Initialized${NC}"
    echo -e "${BLUE}Test directory: $TEST_TEMP_DIR${NC}"
    echo ""
}

# Cleanup test framework
function test_cleanup() {
    # Remove temporary directory
    [[ -n "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
    
    echo ""
    echo -e "${CYAN}📊 Test Results Summary${NC}"
    echo -e "${GREEN}✅ Passed: $PASS_COUNT${NC}"
    echo -e "${RED}❌ Failed: $FAIL_COUNT${NC}"
    echo -e "${YELLOW}⏭️  Skipped: $SKIP_COUNT${NC}"
    echo -e "${BLUE}📋 Total: $TEST_COUNT${NC}"
    
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo -e "\n${RED}Some tests failed!${NC}"
        return 1
    else
        echo -e "\n${GREEN}All tests passed!${NC}"
        return 0
    fi
}

# Start a test case
function test_case() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    TEST_FAILED=false
    ((TEST_COUNT++))
    
    echo -e "${BLUE}🔍 Running: $test_name${NC}"
    
    # Run setup functions
    for setup_func in "${SETUP_FUNCTIONS[@]}"; do
        if declare -f "$setup_func" > /dev/null; then
            "$setup_func"
        fi
    done
}

# End a test case
function test_end() {
    # Run teardown functions
    for teardown_func in "${TEARDOWN_FUNCTIONS[@]}"; do
        if declare -f "$teardown_func" > /dev/null; then
            "$teardown_func"
        fi
    done
    
    if [[ "$TEST_FAILED" == "true" ]]; then
        ((FAIL_COUNT++))
        echo -e "${RED}❌ FAILED: $CURRENT_TEST${NC}"
    else
        ((PASS_COUNT++))
        echo -e "${GREEN}✅ PASSED: $CURRENT_TEST${NC}"
    fi
    echo ""
}

# Skip a test
function test_skip() {
    local reason="$1"
    ((SKIP_COUNT++))
    echo -e "${YELLOW}⏭️  SKIPPED: $CURRENT_TEST - $reason${NC}"
    echo ""
}

# Register setup function
function test_setup() {
    SETUP_FUNCTIONS+=("$1")
}

# Register teardown function
function test_teardown() {
    TEARDOWN_FUNCTIONS+=("$1")
}

# Assertion functions
function assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    Expected: '$expected'${NC}"
        echo -e "${RED}    Actual:   '$actual'${NC}"
        TEST_FAILED=true
    fi
}

function assert_not_equals() {
    local not_expected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    if [[ "$not_expected" == "$actual" ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    Should not equal: '$not_expected'${NC}"
        echo -e "${RED}    But got:          '$actual'${NC}"
        TEST_FAILED=true
    fi
}

function assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    String:    '$haystack'${NC}"
        echo -e "${RED}    Should contain: '$needle'${NC}"
        TEST_FAILED=true
    fi
}

function assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    String:    '$haystack'${NC}"
        echo -e "${RED}    Should not contain: '$needle'${NC}"
        TEST_FAILED=true
    fi
}

function assert_empty() {
    local value="$1"
    local message="${2:-Value should be empty}"
    
    if [[ -n "$value" ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    Expected: empty${NC}"
        echo -e "${RED}    Actual:   '$value'${NC}"
        TEST_FAILED=true
    fi
}

function assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"
    
    if [[ -z "$value" ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    Value should not be empty${NC}"
        TEST_FAILED=true
    fi
}

function assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    File: '$file'${NC}"
        TEST_FAILED=true
    fi
}

function assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"
    
    if [[ -f "$file" ]]; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    File: '$file'${NC}"
        TEST_FAILED=true
    fi
}

function assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"
    
    if ! eval "$command" >/dev/null 2>&1; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    Command: '$command'${NC}"
        TEST_FAILED=true
    fi
}

function assert_command_failure() {
    local command="$1"
    local message="${2:-Command should fail}"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${RED}  ❌ Assertion failed: $message${NC}"
        echo -e "${RED}    Command: '$command'${NC}"
        TEST_FAILED=true
    fi
}

# Mock functions
function mock_command() {
    local command="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"
    
    # Create mock function
    eval "function $command() { echo '$mock_output'; return $mock_exit_code; }"
}

function mock_env_var() {
    local var_name="$1"
    local var_value="$2"
    
    export "$var_name"="$var_value"
}

function unmock_env_var() {
    local var_name="$1"
    unset "$var_name"
}

# Capture command output
function capture_output() {
    local command="$1"
    TEST_OUTPUT=$(eval "$command" 2>/dev/null)
    TEST_STDERR=$(eval "$command" 2>&1 >/dev/null)
}

# Load the bourgie plugin for testing
function load_bourgie_plugin() {
    local plugin_file="$1"
    
    # Mock oh-my-posh to avoid actual initialization
    mock_command "oh-my-posh" "mocked oh-my-posh output"
    
    # Source the plugin
    source "$plugin_file"
}

# Create a mock git repository
function create_mock_git_repo() {
    local repo_dir="$TEST_TEMP_DIR/mock-repo"
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    
    # Initialize git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1
    
    # Create initial commit
    echo "# Test Repository" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    
    echo "$repo_dir"
}

# Mock git commands for testing
function mock_git_commands() {
    mock_command "git" "master"  # Default branch name
    
    # Override specific git commands
    function git() {
        case "$1" in
            "rev-parse")
                case "$2" in
                    "--verify") echo "abc123" ;;
                    "--abbrev-ref") echo "main" ;;
                    *) echo "abc123" ;;
                esac
                ;;
            "status")
                echo "On branch main"
                echo "nothing to commit, working tree clean"
                ;;
            "stash")
                echo "0"
                ;;
            "config")
                case "$3" in
                    "user.name") echo "Test User" ;;
                    "user.email") echo "test@example.com" ;;
                    *) echo "" ;;
                esac
                ;;
            *) echo "mocked git command: $*" ;;
        esac
    }
}