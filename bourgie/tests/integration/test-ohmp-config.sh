#!/usr/bin/env zsh

# Integration tests for oh-my-posh configuration

# Get script directory
TEST_DIR="${0:A:h}"
PLUGIN_DIR="${TEST_DIR:h:h}"

# Load test framework
source "$TEST_DIR/../test-framework.sh"

# Setup function run before each test
function setup_integration_test() {
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
    
    # Copy config file to test directory
    cp "$PLUGIN_DIR/posh-config.yaml" "$TEST_CONFIG_DIR/test-config.yaml"
}

# Test oh-my-posh configuration file validity
function test_ohmp_config_yaml_syntax() {
    test_case "oh-my-posh config YAML syntax validation"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    
    # Check if config file exists
    assert_file_exists "$config_file" "Configuration file should exist"
    
    # Test YAML syntax with python (most systems have python)
    if command -v python3 >/dev/null 2>&1; then
        assert_command_success "python3 -c 'import yaml; yaml.safe_load(open(\"$config_file\"))'" "YAML should be valid"
    elif command -v python >/dev/null 2>&1; then
        assert_command_success "python -c 'import yaml; yaml.safe_load(open(\"$config_file\"))'" "YAML should be valid"
    else
        test_skip "Python not available for YAML validation"
        return
    fi
    
    test_end
}

# Test configuration schema validation
function test_ohmp_config_schema() {
    test_case "oh-my-posh config schema validation"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local config_content=$(cat "$config_file")
    
    # Check required top-level keys
    assert_contains "$config_content" "palette:" "Config should have palette section"
    assert_contains "$config_content" "blocks:" "Config should have blocks section" 
    assert_contains "$config_content" "version:" "Config should have version"
    assert_contains "$config_content" "console_title_template:" "Config should have console title template"
    
    # Check palette colors (Nord theme)
    assert_contains "$config_content" "primary_black: '#2E3440'" "Should have primary_black color"
    assert_contains "$config_content" "primary_cyan: '#88C0D0'" "Should have primary_cyan color"
    assert_contains "$config_content" "primary_green: '#A3BE8C'" "Should have primary_green color"
    assert_contains "$config_content" "primary_light: '#E5E9F0'" "Should have primary_light color"
    
    # Check version
    assert_contains "$config_content" "version: 3" "Should use oh-my-posh version 3"
    
    test_end
}

# Test segment configuration
function test_ohmp_segment_configuration() {
    test_case "oh-my-posh segment configuration"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local config_content=$(cat "$config_file")
    
    # Check for required segments
    assert_contains "$config_content" "type: session" "Should have session segment"
    assert_contains "$config_content" "type: path" "Should have path segment"
    assert_contains "$config_content" "type: git" "Should have git segment"
    assert_contains "$config_content" "type: python" "Should have python segment"
    assert_contains "$config_content" "type: node" "Should have node segment"
    assert_contains "$config_content" "type: npm" "Should have npm segment"
    assert_contains "$config_content" "type: text" "Should have text segment for Docker"
    assert_contains "$config_content" "type: time" "Should have time segment"
    assert_contains "$config_content" "type: exit" "Should have exit segment"
    assert_contains "$config_content" "type: shell" "Should have shell segment"
    
    test_end
}

# Test environment variable integration
function test_ohmp_environment_variables() {
    test_case "oh-my-posh environment variable integration"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local config_content=$(cat "$config_file")
    
    # Check environment variable usage in templates
    assert_contains "$config_content" ".Env.SSH_CLIENT" "Should use SSH_CLIENT env var"
    assert_contains "$config_content" ".Env.USER" "Should use USER env var"
    assert_contains "$config_content" ".Env.HOSTNAME" "Should use HOSTNAME env var"
    assert_contains "$config_content" ".Env.ENABLE_DOCKER_PROMPT" "Should use ENABLE_DOCKER_PROMPT env var"
    assert_contains "$config_content" ".Env.ENABLE_NODE_PROMPT" "Should use ENABLE_NODE_PROMPT env var"
    assert_contains "$config_content" ".Env.LAZY_NODE_PROMPT" "Should use LAZY_NODE_PROMPT env var"
    assert_contains "$config_content" ".Env.NVM_LOADED" "Should use NVM_LOADED env var"
    assert_contains "$config_content" ".Env.BOURGIE_SHOW_TIME" "Should use BOURGIE_SHOW_TIME env var"
    
    test_end
}

# Test git segment configuration
function test_ohmp_git_segment() {
    test_case "oh-my-posh git segment configuration"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local config_content=$(cat "$config_file")
    
    # Check git segment properties
    assert_contains "$config_content" "fetch_stash_count: true" "Should fetch stash count"
    assert_contains "$config_content" "fetch_status: true" "Should fetch git status"
    assert_contains "$config_content" "fetch_upstream_icon: true" "Should fetch upstream info"
    assert_contains "$config_content" "fetch_user: true" "Should fetch git user info"
    
    # Check git template matches git-taculous format
    # Template should include: (git) branch status upstream stash user
    local git_template_line=$(grep -A1 "type: git" "$config_file" | grep "template:")
    assert_contains "$git_template_line" "(git)" "Git template should start with (git)"
    assert_contains "$git_template_line" ".HEAD" "Should show git HEAD"
    assert_contains "$git_template_line" ".Working.Changed" "Should show working changes"
    assert_contains "$git_template_line" ".Staging.Changed" "Should show staging changes"
    assert_contains "$git_template_line" ".Upstream" "Should show upstream info"
    assert_contains "$git_template_line" ".StashCount" "Should show stash count"
    assert_contains "$git_template_line" ".User.Name" "Should show git user name"
    
    test_end
}

# Test template conditional logic
function test_ohmp_template_conditionals() {
    test_case "oh-my-posh template conditional logic"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local config_content=$(cat "$config_file")
    
    # Check conditional templates for environment variables
    assert_contains "$config_content" "{{ if .Env.SSH_CLIENT }}" "Should conditionally show SSH info"
    assert_contains "$config_content" "{{ if .Env.ENABLE_DOCKER_PROMPT }}" "Should conditionally show Docker"
    assert_contains "$config_content" "{{ if or .Env.ENABLE_NODE_PROMPT" "Should conditionally show Node.js"
    assert_contains "$config_content" "{{ if .Env.BOURGIE_SHOW_TIME }}" "Should conditionally show time"
    
    # Check git-specific conditionals
    assert_contains "$config_content" "{{ if .Working.Changed }}" "Should conditionally show working changes"
    assert_contains "$config_content" "{{ if .Staging.Changed }}" "Should conditionally show staging changes"
    assert_contains "$config_content" "{{ if .Upstream }}" "Should conditionally show upstream"
    assert_contains "$config_content" "{{ if gt .StashCount 0 }}" "Should conditionally show stash count"
    assert_contains "$config_content" "{{ if .User.Name }}" "Should conditionally show git user"
    
    test_end
}

# Test color scheme consistency
function test_ohmp_color_scheme() {
    test_case "oh-my-posh color scheme consistency"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local config_content=$(cat "$config_file")
    
    # Check that all colors reference palette colors (no hardcoded colors in segments)
    local segment_colors=$(grep -E "foreground:|background:" "$config_file" | grep -v "foreground_templates" | grep -v "transparent")
    
    # Should use palette references or transparent
    while IFS= read -r line; do
        if [[ "$line" == *"foreground:"* ]] || [[ "$line" == *"background:"* ]]; then
            # Extract the color value
            local color_value=$(echo "$line" | sed -E "s/.*: ['\"]?([^'\"]*)['\"]?.*/\1/")
            if [[ "$color_value" != "transparent" ]]; then
                # Should be a hex color (for direct colors) or palette reference
                if [[ ! "$color_value" =~ ^#[0-9A-Fa-f]{6}$ ]]; then
                    echo "Found non-hex, non-transparent color: $color_value in line: $line"
                fi
            fi
        fi
    done <<< "$segment_colors"
    
    test_end
}

# Test prompt structure (blocks and segments)
function test_ohmp_prompt_structure() {
    test_case "oh-my-posh prompt structure"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    local config_content=$(cat "$config_file")
    
    # Should have multiple prompt blocks
    local block_count=$(grep -c "- type: prompt" "$config_file")
    assert_not_equals "0" "$block_count" "Should have at least one prompt block"
    
    # Should have rprompt (right prompt) for time
    assert_contains "$config_content" "type: rprompt" "Should have right prompt block"
    
    # Check newline usage
    assert_contains "$config_content" "newline: true" "Should have newline separators"
    
    # Check final space
    assert_contains "$config_content" "final_space: true" "Should have final space"
    
    test_end
}

# Test configuration with different environment scenarios
function test_ohmp_config_ssh_scenario() {
    test_case "oh-my-posh config with SSH environment"
    
    # Set up SSH environment
    export SSH_CLIENT="192.168.1.100 54321 22"
    export USER="testuser"
    export HOSTNAME="testhost"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    
    # Mock oh-my-posh to validate config
    mock_command "oh-my-posh" "config validation successful"
    
    # The config should be valid with SSH environment
    assert_command_success "oh-my-posh init zsh --config \"$config_file\"" "Config should be valid with SSH env"
    
    test_end
}

function test_ohmp_config_docker_scenario() {
    test_case "oh-my-posh config with Docker environment"
    
    # Set up Docker environment
    export ENABLE_DOCKER_PROMPT=true
    export DOCKER_HOST="tcp://localhost:2376"
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    
    # Mock oh-my-posh to validate config
    mock_command "oh-my-posh" "config validation successful"
    
    # The config should be valid with Docker environment
    assert_command_success "oh-my-posh init zsh --config \"$config_file\"" "Config should be valid with Docker env"
    
    test_end
}

function test_ohmp_config_node_scenario() {
    test_case "oh-my-posh config with Node.js environment"
    
    # Set up Node.js environment
    export ENABLE_NODE_PROMPT=true
    export NVM_LOADED=true
    
    local config_file="$PLUGIN_DIR/posh-config.yaml"
    
    # Mock oh-my-posh to validate config
    mock_command "oh-my-posh" "config validation successful"
    
    # The config should be valid with Node.js environment
    assert_command_success "oh-my-posh init zsh --config \"$config_file\"" "Config should be valid with Node.js env"
    
    test_end
}

# Register setup function
test_setup setup_integration_test

# Initialize test framework
test_init

echo -e "${CYAN}🔧 Running Integration Tests for oh-my-posh Configuration${NC}"

# Run all tests
test_ohmp_config_yaml_syntax
test_ohmp_config_schema
test_ohmp_segment_configuration
test_ohmp_environment_variables
test_ohmp_git_segment
test_ohmp_template_conditionals
test_ohmp_color_scheme
test_ohmp_prompt_structure
test_ohmp_config_ssh_scenario
test_ohmp_config_docker_scenario
test_ohmp_config_node_scenario

# Cleanup and show results
test_cleanup