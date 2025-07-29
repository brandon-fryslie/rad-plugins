#!/usr/bin/env zsh

# Tests for environment variable handling and validation

# Get script directory
TEST_DIR="${0:A:h}"
PLUGIN_DIR="${TEST_DIR:h:h}"

# Load test framework
source "$TEST_DIR/../test-framework.sh"

# Setup function run before each test
function setup_env_test() {
    # Clean environment completely
    unset ENABLE_DOCKER_PROMPT
    unset ENABLE_NODE_PROMPT
    unset LAZY_NODE_PROMPT
    unset GITTACULOUS_ENABLE_SSH_THEME
    unset BOURGIE_SHOW_TIME
    unset RAD_BOURGIE_DEBUG
    unset RAD_BOURGIE_DEBUG_FILE
    unset SSH_CLIENT
    unset VIRTUAL_ENV
    unset PIPENV_ACTIVE
    unset DOCKER_HOST
    unset USER
    unset HOSTNAME
    unset NVM_LOADED
    unset BOURGIE_NO_AUTO_INIT
    
    # Mock external commands
    mock_command "oh-my-posh" "mocked oh-my-posh output"
    mock_command "hostname" "testhost"
    mock_command "whoami" "testuser"
}

# Test default environment variable values
function test_default_environment_values() {
    test_case "default environment variable values"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Check default values are set correctly
    assert_equals "false" "$GITTACULOUS_ENABLE_SSH_THEME" "SSH theme should default to false"
    assert_equals "false" "$ENABLE_DOCKER_PROMPT" "Docker prompt should default to false"
    assert_equals "false" "$ENABLE_NODE_PROMPT" "Node prompt should default to false"
    assert_equals "false" "$LAZY_NODE_PROMPT" "Lazy Node prompt should default to false"
    assert_equals "false" "$BOURGIE_SHOW_TIME" "Time display should default to false"
    
    test_end
}

# Test SSH environment detection
function test_ssh_environment_detection() {
    test_case "SSH environment detection"
    
    # Test with SSH_CLIENT set
    export SSH_CLIENT="192.168.1.100 54321 22"
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "true" "$GITTACULOUS_ENABLE_SSH_THEME" "SSH theme should be enabled when SSH_CLIENT is set"
    
    test_end
}

function test_ssh_manual_override() {
    test_case "SSH theme manual override"
    
    # Test manual override even without SSH_CLIENT
    export GITTACULOUS_ENABLE_SSH_THEME=true
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "true" "$GITTACULOUS_ENABLE_SSH_THEME" "SSH theme should stay enabled when manually set"
    
    test_end
}

# Test environment variable export
function test_environment_variable_export() {
    test_case "environment variables are properly exported"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Check that key variables are exported (accessible to child processes)
    assert_command_success "printenv GITTACULOUS_ENABLE_SSH_THEME" "GITTACULOUS_ENABLE_SSH_THEME should be exported"
    assert_command_success "printenv ENABLE_DOCKER_PROMPT" "ENABLE_DOCKER_PROMPT should be exported"
    assert_command_success "printenv ENABLE_NODE_PROMPT" "ENABLE_NODE_PROMPT should be exported"
    assert_command_success "printenv LAZY_NODE_PROMPT" "LAZY_NODE_PROMPT should be exported"
    assert_command_success "printenv BOURGIE_SHOW_TIME" "BOURGIE_SHOW_TIME should be exported"
    assert_command_success "printenv USER" "USER should be exported"
    assert_command_success "printenv HOSTNAME" "HOSTNAME should be exported"
    assert_command_success "printenv NVM_LOADED" "NVM_LOADED should be exported"
    
    test_end
}

# Test USER and HOSTNAME fallback
function test_user_hostname_fallback() {
    test_case "USER and HOSTNAME fallback mechanisms"
    
    # Test USER fallback
    unset USER
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "testuser" "$USER" "USER should fallback to whoami result"
    
    # Test HOSTNAME fallback
    unset HOSTNAME
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "testhost" "$HOSTNAME" "HOSTNAME should fallback to hostname command"
    
    test_end
}

# Test NVM lazy loading detection
function test_nvm_lazy_loading_detection() {
    test_case "NVM lazy loading detection"
    
    # Mock zstyle command for NVM lazy loading
    function zstyle() {
        if [[ "$1" == "-t" && "$2" == ":nvm-lazy-load" && "$3" == "nvm-loaded" && "$4" == "yes" ]]; then
            return 0  # NVM is loaded
        else
            return 1  # NVM is not loaded
        fi
    }
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "true" "$NVM_LOADED" "NVM_LOADED should be true when zstyle indicates loaded"
    
    test_end
}

function test_nvm_not_loaded() {
    test_case "NVM not loaded detection"
    
    # Mock zstyle command for NVM not loaded
    function zstyle() {
        return 1  # NVM is not loaded
    }
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "false" "$NVM_LOADED" "NVM_LOADED should be false when zstyle indicates not loaded"
    
    test_end
}

# Test debug environment setup
function test_debug_environment_setup() {
    test_case "debug environment setup"
    
    export RAD_BOURGIE_DEBUG=true
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    local debug_file="${RAD_BOURGIE_DEBUG_FILE:-/tmp/bourgie-debug.log}"
    assert_file_exists "$debug_file" "Debug file should be created when debug is enabled"
    
    local log_content=$(cat "$debug_file")
    assert_contains "$log_content" "BOURGIE DEBUG SESSION STARTED" "Debug log should contain session start marker"
    assert_contains "$log_content" "PID:" "Debug log should contain process ID"
    assert_contains "$log_content" "Shell:" "Debug log should contain shell info"
    assert_contains "$log_content" "PWD:" "Debug log should contain working directory"
    
    test_end
}

function test_debug_file_custom_location() {
    test_case "custom debug file location"
    
    export RAD_BOURGIE_DEBUG=true
    export RAD_BOURGIE_DEBUG_FILE="$TEST_TEMP_DIR/custom-debug.log"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_file_exists "$TEST_TEMP_DIR/custom-debug.log" "Custom debug file should be created"
    assert_file_not_exists "/tmp/bourgie-debug.log" "Default debug file should not be created"
    
    test_end
}

# Test auto-initialization behavior
function test_auto_init_enabled() {
    test_case "auto-initialization enabled by default"
    
    # Mock bourgie_init to track if it was called
    local init_called=false
    function bourgie_init() {
        init_called=true
        echo "bourgie_init was called"
    }
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "true" "$init_called" "bourgie_init should be called during plugin load"
    
    test_end
}

function test_auto_init_disabled() {
    test_case "auto-initialization can be disabled"
    
    export BOURGIE_NO_AUTO_INIT=true
    
    # Mock bourgie_init to track if it was called
    local init_called=false
    function bourgie_init() {
        init_called=true
        echo "bourgie_init was called"
    }
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    assert_equals "false" "$init_called" "bourgie_init should not be called when BOURGIE_NO_AUTO_INIT is true"
    
    test_end
}

# Test environment variable validation
function test_boolean_environment_variables() {
    test_case "boolean environment variable validation"
    
    # Test valid boolean values
    export ENABLE_DOCKER_PROMPT="true"
    export ENABLE_NODE_PROMPT="false"
    export LAZY_NODE_PROMPT="true"
    export GITTACULOUS_ENABLE_SSH_THEME="false"
    export BOURGIE_SHOW_TIME="true"
    export RAD_BOURGIE_DEBUG="false"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # All should remain as set
    assert_equals "true" "$ENABLE_DOCKER_PROMPT" "ENABLE_DOCKER_PROMPT should preserve true"
    assert_equals "false" "$ENABLE_NODE_PROMPT" "ENABLE_NODE_PROMPT should preserve false"
    assert_equals "true" "$LAZY_NODE_PROMPT" "LAZY_NODE_PROMPT should preserve true"
    assert_equals "false" "$GITTACULOUS_ENABLE_SSH_THEME" "GITTACULOUS_ENABLE_SSH_THEME should preserve false"
    assert_equals "true" "$BOURGIE_SHOW_TIME" "BOURGIE_SHOW_TIME should preserve true"
    assert_equals "false" "$RAD_BOURGIE_DEBUG" "RAD_BOURGIE_DEBUG should preserve false"
    
    test_end
}

# Test Docker environment handling
function test_docker_environment_handling() {
    test_case "Docker environment variable handling"
    
    # Test with DOCKER_HOST set
    export DOCKER_HOST="tcp://192.168.1.50:2376"
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-docker-prompt"
    assert_contains "$TEST_OUTPUT" "tcp://192.168.1.50:2376" "Should show Docker host"
    
    # Test with DOCKER_HOST unset
    unset DOCKER_HOST
    capture_output "_get-docker-prompt"
    assert_contains "$TEST_OUTPUT" "unset" "Should show 'unset' when DOCKER_HOST is empty"
    
    test_end
}

# Test Python virtual environment handling
function test_python_venv_handling() {
    test_case "Python virtual environment handling"
    
    # Test with regular virtualenv
    export VIRTUAL_ENV="/home/user/.virtualenvs/my-long-project-name-environment"
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_get-venv-prompt"
    assert_contains "$TEST_OUTPUT" "🐱 Venv:" "Should show venv indicator"
    assert_contains "$TEST_OUTPUT" "environment" "Should show truncated env name"
    
    # Test with pipenv
    export PIPENV_ACTIVE=1
    export VIRTUAL_ENV="/home/user/.local/share/virtualenvs/pipenv-project"
    
    capture_output "_get-venv-prompt"
    assert_contains "$TEST_OUTPUT" "pipenv:" "Should show pipenv indicator"
    assert_contains "$TEST_OUTPUT" "pipenv-project" "Should show pipenv project name"
    
    test_end
}

# Test configuration persistence
function test_configuration_persistence() {
    test_case "configuration changes persist in environment"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Make configuration changes
    bourgie_config docker on
    bourgie_config node lazy
    bourgie_config ssh on
    bourgie_config time on
    bourgie_config debug on
    
    # Check that changes persisted
    assert_equals "true" "$ENABLE_DOCKER_PROMPT" "Docker config should persist"
    assert_equals "true" "$LAZY_NODE_PROMPT" "Lazy Node config should persist"
    assert_equals "false" "$ENABLE_NODE_PROMPT" "Node prompt should be off in lazy mode"
    assert_equals "true" "$GITTACULOUS_ENABLE_SSH_THEME" "SSH theme should persist"
    assert_equals "true" "$BOURGIE_SHOW_TIME" "Time display should persist"
    assert_equals "true" "$RAD_BOURGIE_DEBUG" "Debug should persist"
    
    test_end
}

# Register setup function
test_setup setup_env_test

# Initialize test framework
test_init

echo -e "${CYAN}🌍 Running Environment Variable Tests${NC}"

# Run all tests
test_default_environment_values
test_ssh_environment_detection
test_ssh_manual_override
test_environment_variable_export
test_user_hostname_fallback
test_nvm_lazy_loading_detection
test_nvm_not_loaded
test_debug_environment_setup
test_debug_file_custom_location
test_auto_init_enabled
test_auto_init_disabled
test_boolean_environment_variables
test_docker_environment_handling
test_python_venv_handling
test_configuration_persistence

# Cleanup and show results
test_cleanup