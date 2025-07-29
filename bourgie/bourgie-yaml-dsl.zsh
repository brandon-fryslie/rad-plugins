#!/usr/bin/env zsh

# Bourgie YAML DSL - Lightweight YAML abstraction with inline zsh functions
# Maintains familiar oh-my-posh YAML structure with syntactic sugar for custom segments

# Global state for DSL processing
typeset -g BOURGIE_DSL_FUNCTIONS=()
typeset -g BOURGIE_DSL_TEMPLATES=()
typeset -g BOURGIE_DSL_OUTPUT=""

# Initialize DSL processor
function yaml_dsl_init() {
    BOURGIE_DSL_FUNCTIONS=()
    BOURGIE_DSL_TEMPLATES=()
    BOURGIE_DSL_OUTPUT=""
    
    if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
        _bourgie_debug "[YAML-DSL] Initialized processor"
    fi
}

# Process YAML DSL file and generate standard oh-my-posh config + zsh functions
function yaml_dsl_process() {
    local input_file="$1"
    local output_config="${2:-${input_file%.*}-compiled.yaml}"
    local output_functions="${3:-${input_file%.*}-functions.zsh}"
    
    if [[ ! -f "$input_file" ]]; then
        echo "❌ DSL file not found: $input_file"
        return 1
    fi
    
    echo "🔄 Processing YAML DSL: $input_file"
    
    # Initialize processor
    yaml_dsl_init
    
    # Parse the DSL file
    if ! yaml_dsl_parse "$input_file"; then
        echo "❌ Failed to parse DSL file"
        return 1
    fi
    
    # Generate oh-my-posh config
    if ! yaml_dsl_generate_config "$input_file" "$output_config"; then
        echo "❌ Failed to generate oh-my-posh config"
        return 1
    fi
    
    # Generate zsh functions
    if ! yaml_dsl_generate_functions "$output_functions"; then
        echo "❌ Failed to generate zsh functions"
        return 1
    fi
    
    echo "✅ Generated files:"
    echo "  📄 Config: $output_config"
    echo "  ⚡ Functions: $output_functions"
    
    return 0
}

# Parse YAML DSL file and extract inline functions
function yaml_dsl_parse() {
    local input_file="$1"
    local current_function=""
    local function_body=""
    local in_function=false
    local indent_level=0
    
    while IFS= read -r line; do
        # Check for inline function definition
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*-\>[[:space:]]*$ ]]; then
            # Start of inline function: name: ->
            current_function="${match[1]}"
            function_body=""
            in_function=true
            indent_level=$(( ${#line} - ${#${line##[[:space:]]*}} + 2 ))
            
            if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
                _bourgie_debug "[YAML-DSL] Found function: $current_function"
            fi
            
        elif [[ "$in_function" == "true" ]]; then
            local line_indent=$(( ${#line} - ${#${line##[[:space:]]*}} ))
            
            # Check if we're still inside the function (proper indentation)
            if [[ $line_indent -ge $indent_level ]] || [[ -z "${line// }" ]]; then
                # Remove the base indentation and add to function body
                local cleaned_line="${line:$indent_level}"
                function_body="$function_body$cleaned_line"$'\n'
            else
                # Function ended, save it
                yaml_dsl_save_function "$current_function" "$function_body"
                in_function=false
                current_function=""
                function_body=""
            fi
        fi
    done < "$input_file"
    
    # Save final function if we ended while inside one
    if [[ "$in_function" == "true" && -n "$current_function" ]]; then
        yaml_dsl_save_function "$current_function" "$function_body"
    fi
    
    return 0
}

# Save extracted function
function yaml_dsl_save_function() {
    local function_name="$1"
    local function_body="$2"
    
    # Convert CoffeeScript-style syntax to zsh
    local zsh_function=$(yaml_dsl_convert_function "$function_body")
    
    BOURGIE_DSL_FUNCTIONS+=("$function_name:$zsh_function")
    
    if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
        _bourgie_debug "[YAML-DSL] Saved function: $function_name"
    fi
}

# Convert CoffeeScript-style function body to zsh
function yaml_dsl_convert_function() {
    local coffee_body="$1"
    local zsh_body=""
    
    # Process each line
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "${line// }" ]] && continue
        
        # Convert CoffeeScript-style syntax to zsh
        line=$(yaml_dsl_convert_line "$line")
        zsh_body="$zsh_body    $line"$'\n'
        
    done <<< "$coffee_body"
    
    echo "$zsh_body"
}

# Convert individual line from CoffeeScript style to zsh
function yaml_dsl_convert_line() {
    local line="$1"
    
    # Remove leading/trailing whitespace
    line="${line## }"
    line="${line%% }"
    
    # Convert common CoffeeScript patterns to zsh
    
    # if condition then action -> if [[ condition ]]; then action; fi
    if [[ "$line" =~ ^if[[:space:]]+(.+)[[:space:]]+then[[:space:]]+(.+)$ ]]; then
        echo "if [[ ${match[1]} ]]; then ${match[2]}; fi"
        return
    fi
    
    # return value -> echo "value"
    if [[ "$line" =~ ^return[[:space:]]+(.+)$ ]]; then
        echo "echo \"${match[1]}\""
        return
    fi
    
    # variable = value -> local variable="value"
    if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
        echo "local ${match[1]}=\"${match[2]}\""
        return
    fi
    
    # @env -> $ENV (environment variable reference)
    line="${line//@([a-zA-Z_][a-zA-Z0-9_]*)/\$${match[1]}}"
    
    # #{expression} -> $(expression) (command substitution)
    line="${line//\#\{([^}]*)\}/\$(${match[1]})}"
    
    # "string" interpolation with #{} -> "string" with $()
    while [[ "$line" =~ \#\{([^}]*)\} ]]; do
        line="${line//#\{${match[1]}\}/\$(${match[1]})}"
    done
    
    # Default: return line as-is (for plain zsh commands)
    echo "$line"
}

# Generate oh-my-posh config file (replace inline functions with templates)
function yaml_dsl_generate_config() {
    local input_file="$1"
    local output_file="$2"
    local processed_content=""
    local in_function=false
    local indent_level=0
    
    while IFS= read -r line; do
        # Check for inline function definition
        if [[ "$line" =~ ^([[:space:]]*)([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*-\>[[:space:]]*$ ]]; then
            # Replace with template call
            local indent="${match[1]}"
            local function_name="${match[2]}"
            processed_content="$processed_content${indent}template: '{{ .Env._BOURGIE_${function_name} }}'"$'\n'
            in_function=true
            indent_level=$(( ${#line} - ${#${line##[[:space:]]*}} + 2 ))
            
        elif [[ "$in_function" == "true" ]]; then
            local line_indent=$(( ${#line} - ${#${line##[[:space:]]*}} ))
            
            # Skip function body lines
            if [[ $line_indent -lt $indent_level ]] && [[ -n "${line// }" ]]; then
                # Function ended, process this line normally
                processed_content="$processed_content$line"$'\n'
                in_function=false
            fi
            # Otherwise skip the line (it's part of the function body)
            
        else
            # Normal YAML line, keep as-is
            processed_content="$processed_content$line"$'\n'
        fi
    done < "$input_file"
    
    # Write processed content to output file
    echo "$processed_content" > "$output_file"
    
    if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
        _bourgie_debug "[YAML-DSL] Generated config: $output_file"
    fi
    
    return 0
}

# Generate zsh functions file
function yaml_dsl_generate_functions() {
    local output_file="$1"
    
    # Create header
    local functions_content="#!/usr/bin/env zsh

# Generated zsh functions for Bourgie YAML DSL
# This file contains custom segment functions defined in the DSL

"
    
    # Generate each function
    for func_def in "${BOURGIE_DSL_FUNCTIONS[@]}"; do
        local function_name="${func_def%%:*}"
        local function_body="${func_def#*:}"
        
        functions_content="$functions_content# Custom segment function: $function_name
function _bourgie_dsl_$function_name() {
$function_body
}

# Export function result to environment for oh-my-posh template
export _BOURGIE_$function_name=\"\$(_bourgie_dsl_$function_name)\"

"
    done
    
    # Add footer with initialization
    functions_content="$functions_content
# Initialize all DSL functions
function bourgie_dsl_init_functions() {
    for func_def in \"${BOURGIE_DSL_FUNCTIONS[@]}\"; do
        local function_name=\"\${func_def%%:*}\"
        export \"_BOURGIE_\$function_name\"=\"\$(_bourgie_dsl_\$function_name)\"
    done
}

# Auto-initialize if not disabled
if [[ \"\$BOURGIE_DSL_NO_AUTO_INIT\" != \"true\" ]]; then
    bourgie_dsl_init_functions
fi
"
    
    # Write to file
    echo "$functions_content" > "$output_file"
    chmod +x "$output_file"
    
    if [[ "$RAD_BOURGIE_DEBUG" == "true" ]]; then
        _bourgie_debug "[YAML-DSL] Generated functions: $output_file"
    fi
    
    return 0
}

# Validate YAML DSL syntax
function yaml_dsl_validate() {
    local input_file="$1"
    local errors=0
    
    echo "🔍 Validating YAML DSL: $input_file"
    
    # Check if file exists
    if [[ ! -f "$input_file" ]]; then
        echo "❌ File not found: $input_file"
        return 1
    fi
    
    # Basic YAML syntax validation
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$input_file'))" 2>/dev/null; then
            echo "❌ Invalid YAML syntax"
            ((errors++))
        fi
    elif command -v python >/dev/null 2>&1; then
        if ! python -c "import yaml; yaml.safe_load(open('$input_file'))" 2>/dev/null; then
            echo "❌ Invalid YAML syntax" 
            ((errors++))
        fi
    else
        echo "⚠️  Python not available for YAML validation"
    fi
    
    # Check for balanced inline functions
    local function_starts=$(grep -c ': ->$' "$input_file" 2>/dev/null || echo "0")
    if [[ $function_starts -gt 0 ]]; then
        echo "✅ Found $function_starts inline function(s)"
    fi
    
    # Validate oh-my-posh required structure
    if ! grep -q "blocks:" "$input_file"; then
        echo "❌ Missing required 'blocks:' section"
        ((errors++))
    fi
    
    if ! grep -q "version:" "$input_file"; then
        echo "❌ Missing required 'version:' field"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        echo "✅ YAML DSL validation passed"
        return 0
    else
        echo "❌ Found $errors validation errors"
        return 1
    fi
}

# Interactive preview of generated functions
function yaml_dsl_preview() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        echo "❌ DSL file not found: $input_file"
        return 1
    fi
    
    echo "👀 Previewing YAML DSL functions: $input_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Parse the file to extract functions
    yaml_dsl_init
    yaml_dsl_parse "$input_file"
    
    # Display found functions
    if [[ ${#BOURGIE_DSL_FUNCTIONS[@]} -eq 0 ]]; then
        echo "No inline functions found in DSL file"
        return 0
    fi
    
    for func_def in "${BOURGIE_DSL_FUNCTIONS[@]}"; do
        local function_name="${func_def%%:*}"
        local function_body="${func_def#*:}"
        
        echo ""
        echo "🔧 Function: $function_name"
        echo "   Generated zsh code:"
        echo "$function_body" | sed 's/^/     │ /'
        echo ""
    done
}

# Command-line interface
function yaml_dsl_main() {
    case "$1" in
        "process"|"compile")
            shift
            yaml_dsl_process "$@"
            ;;
        "validate")
            shift
            yaml_dsl_validate "$@"
            ;;
        "preview")
            shift  
            yaml_dsl_preview "$@"
            ;;
        "help"|"--help"|"-h")
            echo "Bourgie YAML DSL Processor"
            echo ""
            echo "Usage:"
            echo "  $0 process <input.yaml> [config.yaml] [functions.zsh]"
            echo "  $0 validate <input.yaml>"  
            echo "  $0 preview <input.yaml>"
            echo "  $0 help"
            echo ""
            echo "The YAML DSL allows you to define custom segment functions inline using"
            echo "CoffeeScript-style syntax within standard oh-my-posh YAML configuration."
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Export functions for external use
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${(%):-%x}" == "${0:A}" ]]; then
    yaml_dsl_main "$@"
fi