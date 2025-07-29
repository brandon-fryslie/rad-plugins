#!/usr/bin/env zsh

# Unit tests for bourgie plugin functions

# Get script directory
TEST_DIR="${0:A:h}"
PLUGIN_DIR="${TEST_DIR:h:h}"

# Load test framework
source "$TEST_DIR/../test-framework.sh"

# Setup function run before each test
function setup_test() {
    # Clean environment
    unset ENABLE_DOCKER_PROMPT
    unset ENABLE_NODE_PROMPT
    unset LAZY_NODE_PROMPT
    unset GITTACULOUS_ENABLE_SSH_THEME
    unset BOURGIE_SHOW_TIME
    unset RAD_BOURGIE_DEBUG
    unset SSH_CLIENT
    unset VIRTUAL_ENV
    unset DOCKER_HOST
    
    # Mock external commands
    mock_git_commands
    mock_command "node" "v18.15.0"
    mock_command "npm" "8.5.5"
    mock_command "hostname" "testhost"
    mock_command "whoami" "testuser"
}

# Test _bourgie_debug function
function test_bourgie_debug_disabled() {
    test_case "bourgie_debug when debugging is disabled"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Debug should be disabled by default
    capture_output "_bourgie_debug 'test message'"
    assert_empty "$TEST_OUTPUT" "Debug output should be empty when disabled"
    
    test_end
}

function test_bourgie_debug_enabled() {
    test_case "bourgie_debug when debugging is enabled"
    
    export RAD_BOURGIE_DEBUG=true
    export RAD_BOURGIE_DEBUG_FILE="$TEST_TEMP_DIR/test-debug.log"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    _bourgie_debug "test debug message"
    
    assert_file_exists "$RAD_BOURGIE_DEBUG_FILE" "Debug file should be created"
    
    local log_content=$(cat "$RAD_BOURGIE_DEBUG_FILE")
    assert_contains "$log_content" "test debug message" "Debug message should be in log file"
    assert_contains "$log_content" "[BOURGIE DEBUG]" "Log should contain debug marker"
    
    test_end
}

# Test _get-docker-prompt function
function test_get_docker_prompt_unset() {
    test_case "get-docker-prompt when DOCKER_HOST is unset"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-docker-prompt"
    assert_contains "$TEST_OUTPUT" "🐳 unset" "Should show 'unset' when DOCKER_HOST is empty"
    
    test_end
}

function test_get_docker_prompt_set() {
    test_case "get-docker-prompt when DOCKER_HOST is set"
    
    export DOCKER_HOST="tcp://localhost:2376"
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-docker-prompt"
    assert_contains "$TEST_OUTPUT" "🐳 tcp://localhost:2376" "Should show DOCKER_HOST value"
    
    test_end
}

# Test _get-node-prompt function
function test_get_node_prompt() {
    test_case "get-node-prompt returns version info"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-node-prompt"
    assert_contains "$TEST_OUTPUT" "⬢ v18.15.0" "Should show Node.js version"
    assert_contains "$TEST_OUTPUT" "npm v8.5.5" "Should show npm version"
    
    test_end
}

function test_get_node_prompt_not_installed() {
    test_case "get-node-prompt when Node.js is not installed"
    
    mock_command "node" "" 1  # Mock command failure
    mock_command "npm" "" 1   # Mock command failure
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-node-prompt"
    assert_contains "$TEST_OUTPUT" "⬢ none" "Should show 'none' when Node.js not available"
    assert_contains "$TEST_OUTPUT" "npm none" "Should show 'none' when npm not available"
    
    test_end
}

# Test _get-venv-prompt function  
function test_get_venv_prompt_no_venv() {
    test_case "get-venv-prompt when no virtual environment is active"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-venv-prompt"
    assert_empty "$TEST_OUTPUT" "Should return empty when no venv is active"
    
    test_end
}

function test_get_venv_prompt_with_venv() {
    test_case "get-venv-prompt when virtual environment is active"
    
    export VIRTUAL_ENV="/path/to/my-project-env"
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-venv-prompt"
    assert_contains "$TEST_OUTPUT" "🐱 Venv:" "Should show venv indicator"
    assert_contains "$TEST_OUTPUT" "my-project-env" "Should show truncated venv name"
    
    test_end
}

function test_get_venv_prompt_pipenv() {
    test_case "get-venv-prompt with pipenv environment"
    
    export VIRTUAL_ENV="/path/to/pipenv-env"
    export PIPENV_ACTIVE=1
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-venv-prompt"
    assert_contains "$TEST_OUTPUT" "pipenv:" "Should show pipenv indicator"
    assert_contains "$TEST_OUTPUT" "pipenv-env" "Should show pipenv env name"
    
    test_end
}

# Test _get-current-dir-prompt function
function test_get_current_dir_prompt_no_ssh() {
    test_case "get-current-dir-prompt without SSH"
    
    export PWD="/home/testuser/projects"
    export HOME="/home/testuser"
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-current-dir-prompt"
    assert_contains "$TEST_OUTPUT" "(~/projects)" "Should show home-relative path"
    assert_not_contains "$TEST_OUTPUT" "@" "Should not contain SSH info"
    
    test_end
}

function test_get_current_dir_prompt_with_ssh() {
    test_case "get-current-dir-prompt with SSH enabled"
    
    export PWD="/home/testuser/projects"
    export HOME="/home/testuser"
    export GITTACULOUS_ENABLE_SSH_THEME=true
    export SSH_CLIENT="192.168.1.100 54321 22"
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-current-dir-prompt"
    assert_contains "$TEST_OUTPUT" "testuser@testhost" "Should show user@hostname"
    assert_contains "$TEST_OUTPUT" "(~/projects)" "Should show directory path"
    
    test_end
}

# Test bourgie_init function
function test_bourgie_init_no_ohmp() {
    test_case "bourgie_init when oh-my-posh is not installed"
    
    # Mock oh-my-posh as not found
    function oh-my-posh() { return 127; }  # Command not found
    mock_command "command" "" 1  # command -v will fail
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "bourgie_init"
    assert_contains "$TEST_OUTPUT" "oh-my-posh not found" "Should warn when oh-my-posh is missing"
    
    test_end
}

function test_bourgie_init_missing_config() {
    test_case "bourgie_init when config file is missing"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Move the config file temporarily
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local backup_file="$config_file.test-backup"
    
    [[ -f "$config_file" ]] && mv "$config_file" "$backup_file"
    
    capture_output "bourgie_init"
    assert_contains "$TEST_OUTPUT" "posh-config.yaml not found" "Should warn when config is missing"
    
    # Restore config file
    [[ -f "$backup_file" ]] && mv "$backup_file" "$config_file"
    
    test_end
}

# Test bourgie_config function basic functionality
function test_bourgie_config_docker_enable() {
    test_case "bourgie_config docker enable"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "bourgie_config docker on"
    assert_equals "true" "$ENABLE_DOCKER_PROMPT" "Docker prompt should be enabled"
    assert_contains "$TEST_OUTPUT" "Docker prompt enabled" "Should show success message"
    
    test_end
}

function test_bourgie_config_docker_disable() {
    test_case "bourgie_config docker disable"
    
    export ENABLE_DOCKER_PROMPT=true
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "bourgie_config docker off"
    assert_equals "false" "$ENABLE_DOCKER_PROMPT" "Docker prompt should be disabled"
    assert_contains "$TEST_OUTPUT" "Docker prompt disabled" "Should show success message"
    
    test_end
}

function test_bourgie_config_node_modes() {
    test_case "bourgie_config node different modes"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Test 'on' mode
    capture_output "bourgie_config node on"
    assert_equals "true" "$ENABLE_NODE_PROMPT" "Node prompt should be enabled"
    assert_equals "false" "$LAZY_NODE_PROMPT" "Lazy mode should be disabled"
    
    # Test 'lazy' mode
    capture_output "bourgie_config node lazy"
    assert_equals "false" "$ENABLE_NODE_PROMPT" "Node prompt should be disabled in lazy mode"
    assert_equals "true" "$LAZY_NODE_PROMPT" "Lazy mode should be enabled"
    
    # Test 'off' mode
    capture_output "bourgie_config node off"
    assert_equals "false" "$ENABLE_NODE_PROMPT" "Node prompt should be disabled"
    
    test_end
}

function test_bourgie_config_status() {
    test_case "bourgie_config status display"
    
    export ENABLE_DOCKER_PROMPT=true
    export ENABLE_NODE_PROMPT=false
    export LAZY_NODE_PROMPT=true
    export GITTACULOUS_ENABLE_SSH_THEME=true
    export BOURGIE_SHOW_TIME=false
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "bourgie_config status"
    assert_contains "$TEST_OUTPUT" "SSH Theme: true" "Should show SSH theme status"
    assert_contains "$TEST_OUTPUT" "Docker Prompt: true" "Should show Docker prompt status"
    assert_contains "$TEST_OUTPUT" "Node Prompt: false" "Should show Node prompt status"
    assert_contains "$TEST_OUTPUT" "Lazy Node Prompt: true" "Should show lazy Node status"
    assert_contains "$TEST_OUTPUT" "Show Time: false" "Should show time display status"
    
    test_end
}

# Register setup function
test_setup setup_test

# Initialize test framework
test_init

echo -e "${CYAN}🧪 Running Unit Tests for Plugin Functions${NC}"

# Run all tests
test_bourgie_debug_disabled
test_bourgie_debug_enabled
test_get_docker_prompt_unset
test_get_docker_prompt_set
test_get_node_prompt
test_get_node_prompt_not_installed
test_get_venv_prompt_no_venv
test_get_venv_prompt_with_venv
test_get_venv_prompt_pipenv
test_get_current_dir_prompt_no_ssh
test_get_current_dir_prompt_with_ssh
test_bourgie_init_no_ohmp
test_bourgie_init_missing_config
test_bourgie_config_docker_enable
test_bourgie_config_docker_disable
test_bourgie_config_node_modes
test_bourgie_config_status

# Cleanup and show results
test_cleanup