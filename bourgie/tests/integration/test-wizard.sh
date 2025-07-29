#!/usr/bin/env zsh

# Integration tests for interactive wizard functionality

# Get script directory
TEST_DIR="${0:A:h}"
PLUGIN_DIR="${TEST_DIR:h:h}"

# Load test framework
source "$TEST_DIR/../test-framework.sh"

# Setup function run before each test
function setup_wizard_test() {
    # Clean environment
    unset ENABLE_DOCKER_PROMPT
    unset ENABLE_NODE_PROMPT
    unset LAZY_NODE_PROMPT
    unset GITTACULOUS_ENABLE_SSH_THEME
    unset BOURGIE_SHOW_TIME
    unset RAD_BOURGIE_DEBUG
    
    # Mock external commands
    mock_git_commands
    mock_command "oh-my-posh" "mocked oh-my-posh output"
}

# Helper function to simulate user input
function simulate_user_input() {
    local responses=("$@")
    local response_file="$TEST_TEMP_DIR/user_responses"
    
    # Write responses to a file
    printf '%s\n' "${responses[@]}" > "$response_file"
    
    # Override the read function to read from our file
    local line_counter=0
    function read() {
        ((line_counter++))
        local response=$(sed -n "${line_counter}p" "$response_file")
        echo "$response"
        return 0
    }
}

# Test wizard helper functions
function test_wizard_header() {
    test_case "wizard header display"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_bourgie_show_header"
    assert_contains "$TEST_OUTPUT" "Bourgie Theme Configuration" "Should show theme name"
    assert_contains "$TEST_OUTPUT" "Interactive Setup" "Should show wizard description"
    assert_contains "$TEST_OUTPUT" "╔" "Should have header border"
    assert_contains "$TEST_OUTPUT" "╚" "Should have footer border"
    
    test_end
}

function test_wizard_status_display() {
    test_case "wizard status display"
    
    # Set some configuration values
    export GITTACULOUS_ENABLE_SSH_THEME=true
    export ENABLE_DOCKER_PROMPT=false
    export ENABLE_NODE_PROMPT=true
    export LAZY_NODE_PROMPT=false
    export BOURGIE_SHOW_TIME=true
    export RAD_BOURGIE_DEBUG=false
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "_bourgie_show_current_status"
    assert_contains "$TEST_OUTPUT" "SSH Theme:       true" "Should show SSH theme status"
    assert_contains "$TEST_OUTPUT" "Docker Prompt:   false" "Should show Docker prompt status"
    assert_contains "$TEST_OUTPUT" "Node.js Prompt:  true" "Should show Node.js prompt status"
    assert_contains "$TEST_OUTPUT" "Lazy: false" "Should show lazy Node.js status"
    assert_contains "$TEST_OUTPUT" "Time Display:    true" "Should show time display status"
    assert_contains "$TEST_OUTPUT" "Debug Logging:   false" "Should show debug logging status"
    
    test_end
}

function test_wizard_prompt_user() {
    test_case "wizard user prompt function"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user input
    simulate_user_input "test response"
    
    local result=$(_bourgie_prompt_user "Enter something")
    assert_equals "test response" "$result" "Should return user input"
    
    test_end
}

# Test individual wizard functions
function test_wizard_docker_enable() {
    test_case "wizard Docker configuration - enable"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing 'yes'
    simulate_user_input "y"
    
    _bourgie_wizard_docker
    assert_equals "true" "$ENABLE_DOCKER_PROMPT" "Docker prompt should be enabled"
    
    test_end
}

function test_wizard_docker_disable() {
    test_case "wizard Docker configuration - disable"
    
    export ENABLE_DOCKER_PROMPT=true
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing 'no' 
    simulate_user_input "n"
    
    _bourgie_wizard_docker
    assert_equals "false" "$ENABLE_DOCKER_PROMPT" "Docker prompt should be disabled"
    
    test_end
}

function test_wizard_node_always_on() {
    test_case "wizard Node.js configuration - always on"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing option 1 (always on)
    simulate_user_input "1"
    
    _bourgie_wizard_node
    assert_equals "true" "$ENABLE_NODE_PROMPT" "Node prompt should be enabled"
    assert_equals "false" "$LAZY_NODE_PROMPT" "Lazy mode should be disabled"
    
    test_end
}

function test_wizard_node_lazy() {
    test_case "wizard Node.js configuration - lazy mode"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing option 2 (lazy)
    simulate_user_input "2"
    
    _bourgie_wizard_node
    assert_equals "false" "$ENABLE_NODE_PROMPT" "Node prompt should be disabled"
    assert_equals "true" "$LAZY_NODE_PROMPT" "Lazy mode should be enabled"
    
    test_end
}

function test_wizard_node_disabled() {
    test_case "wizard Node.js configuration - disabled"
    
    export ENABLE_NODE_PROMPT=true
    export LAZY_NODE_PROMPT=true
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing option 3 (disabled)
    simulate_user_input "3"
    
    _bourgie_wizard_node
    assert_equals "false" "$ENABLE_NODE_PROMPT" "Node prompt should be disabled"
    assert_equals "false" "$LAZY_NODE_PROMPT" "Lazy mode should be disabled"
    
    test_end
}

function test_wizard_ssh_enable() {
    test_case "wizard SSH theme configuration - enable"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing 'yes'
    simulate_user_input "yes"
    
    _bourgie_wizard_ssh
    assert_equals "true" "$GITTACULOUS_ENABLE_SSH_THEME" "SSH theme should be enabled"
    
    test_end
}

function test_wizard_time_enable() {
    test_case "wizard time display configuration - enable"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing 'true'
    simulate_user_input "true"
    
    _bourgie_wizard_time
    assert_equals "true" "$BOURGIE_SHOW_TIME" "Time display should be enabled"
    
    test_end
}

function test_wizard_debug_enable() {
    test_case "wizard debug logging configuration - enable"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user choosing '1'
    simulate_user_input "1"
    
    _bourgie_wizard_debug
    assert_equals "true" "$RAD_BOURGIE_DEBUG" "Debug logging should be enabled"
    
    test_end
}

# Test main wizard flow
function test_wizard_individual_options() {
    test_case "wizard main menu - individual options"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Test SSH configuration option (1)
    simulate_user_input "1" "y" "q"
    
    capture_output "_bourgie_run_wizard"
    assert_contains "$TEST_OUTPUT" "🚀 Configuration Options:" "Should show main menu"
    assert_contains "$TEST_OUTPUT" "[1] Configure SSH Theme" "Should show SSH option"
    assert_contains "$TEST_OUTPUT" "[2] Configure Docker Prompt" "Should show Docker option"
    assert_contains "$TEST_OUTPUT" "[q] Quit" "Should show quit option"
    
    test_end
}

function test_wizard_full_setup() {
    test_case "wizard main menu - full setup option"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Test full setup option (6) with all 'no' responses
    simulate_user_input "6" "n" "n" "3" "n" "n" "q"
    
    _bourgie_run_wizard
    
    # All options should be disabled after full setup with 'no' responses
    assert_equals "false" "$GITTACULOUS_ENABLE_SSH_THEME" "SSH should be disabled"
    assert_equals "false" "$ENABLE_DOCKER_PROMPT" "Docker should be disabled"
    assert_equals "false" "$ENABLE_NODE_PROMPT" "Node should be disabled"
    assert_equals "false" "$BOURGIE_SHOW_TIME" "Time should be disabled"
    assert_equals "false" "$RAD_BOURGIE_DEBUG" "Debug should be disabled"
    
    test_end
}

function test_wizard_invalid_option() {
    test_case "wizard main menu - invalid option handling"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Test invalid option then quit
    simulate_user_input "99" "q"
    
    capture_output "_bourgie_run_wizard"
    assert_contains "$TEST_OUTPUT" "❌ Invalid option" "Should show error for invalid option"
    
    test_end
}

# Test bourgie_config integration with wizard
function test_bourgie_config_no_args_launches_wizard() {
    test_case "bourgie_config with no arguments launches wizard"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user quitting immediately
    simulate_user_input "q"
    
    capture_output "bourgie_config"
    assert_contains "$TEST_OUTPUT" "🎨 Bourgie Theme Configuration" "Should show wizard header"
    assert_contains "$TEST_OUTPUT" "🚀 Configuration Options:" "Should show wizard menu"
    
    test_end
}

function test_bourgie_config_wizard_command() {
    test_case "bourgie_config wizard command launches wizard"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Mock user quitting immediately
    simulate_user_input "q"
    
    capture_output "bourgie_config wizard"
    assert_contains "$TEST_OUTPUT" "🎨 Bourgie Theme Configuration" "Should show wizard header"
    
    test_end
}

function test_bourgie_config_backward_compatibility() {
    test_case "bourgie_config maintains CLI backward compatibility"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    # Test traditional CLI commands still work
    capture_output "bourgie_config docker on"
    assert_equals "true" "$ENABLE_DOCKER_PROMPT" "CLI docker command should work"
    assert_contains "$TEST_OUTPUT" "Docker prompt enabled" "Should show success message"
    
    capture_output "bourgie_config node lazy"
    assert_equals "true" "$LAZY_NODE_PROMPT" "CLI node lazy command should work"
    
    capture_output "bourgie_config status"
    assert_contains "$TEST_OUTPUT" "Bourgie Theme Configuration:" "CLI status command should work"
    
    test_end
}

function test_bourgie_config_help_message() {
    test_case "bourgie_config shows enhanced help message"
    
    load_bourgie_plugin "$PLUGIN_DIR/bourgie.plugin.zsh"
    
    capture_output "bourgie_config invalid_command"
    assert_contains "$TEST_OUTPUT" "🎨 Bourgie Theme Configuration" "Should show themed help header"
    assert_contains "$TEST_OUTPUT" "📋 Interactive Commands:" "Should show interactive commands section"
    assert_contains "$TEST_OUTPUT" "⚙️  Traditional CLI Commands:" "Should show CLI commands section"
    assert_contains "$TEST_OUTPUT" "💡 Tip: Run 'bourgie_config' without arguments" "Should show helpful tip"
    
    test_end
}

# Register setup function
test_setup setup_wizard_test

# Initialize test framework
test_init

echo -e "${CYAN}🧙‍♂️ Running Integration Tests for Interactive Wizard${NC}"

# Run all tests
test_wizard_header
test_wizard_status_display
test_wizard_prompt_user
test_wizard_docker_enable
test_wizard_docker_disable
test_wizard_node_always_on
test_wizard_node_lazy
test_wizard_node_disabled
test_wizard_ssh_enable
test_wizard_time_enable
test_wizard_debug_enable
test_wizard_individual_options
test_wizard_full_setup
test_wizard_invalid_option
test_bourgie_config_no_args_launches_wizard
test_bourgie_config_wizard_command
test_bourgie_config_backward_compatibility
test_bourgie_config_help_message

# Cleanup and show results
test_cleanup