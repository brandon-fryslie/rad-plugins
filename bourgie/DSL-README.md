# Bourgie DSL - Domain Specific Language for oh-my-posh

The Bourgie DSL provides an intuitive, readable way to define oh-my-posh prompt segments using natural zsh syntax. Instead of writing verbose YAML configurations, you can use function calls and helper utilities to build your prompt.

## 🎯 Key Features

- **Natural Syntax** - Use familiar function calls instead of YAML
- **Type Safety** - Built-in validation and error checking  
- **Color Management** - Named colors with semantic meaning
- **Template Helpers** - Shortcuts for common template patterns
- **Conditional Logic** - Easy-to-read conditional segment rendering
- **Modular Design** - Reusable components and styling helpers
- **YAML Compilation** - Generates standard oh-my-posh configuration files

## 🚀 Quick Start

### 1. Basic Usage

```zsh
#!/usr/bin/env zsh

# Load the DSL
source bourgie-dsl.zsh

# Initialize
dsl_init

# Create a simple prompt
dsl_block "prompt" "left"

# Add directory segment
dsl_path "({{ .Path }}) " --foreground "cyan"

# Add git information  
dsl_git "$(dsl_if_git "({{ .HEAD }}) ")" --foreground "green"

# Add prompt character
dsl_text "❯ " --foreground "blue"

# Compile to YAML
dsl_compile "my-theme.yaml"
```

### 2. Using the Compiler

```bash
# Compile a DSL file
./dsl-compiler.zsh compile my-theme.dsl my-theme.yaml

# Validate DSL syntax
./dsl-compiler.zsh validate my-theme.dsl

# Interactive mode
./dsl-compiler.zsh interactive

# Generate example
./dsl-compiler.zsh example
```

## 📚 DSL Reference

### Core Functions

#### `dsl_init()`
Initialize the DSL environment and reset state.

#### `dsl_block <type> [alignment]`
Create a new prompt block.
- `type`: "prompt" or "rprompt" 
- `alignment`: "left", "right", "center"

```zsh
dsl_block "prompt" "left"    # Main prompt block
dsl_rprompt                  # Right prompt (shortcut)
```

#### `dsl_newline()`
Add a newline to separate prompt sections.

### Segment Functions

#### `dsl_text <template> [options...]`
Create a text segment with static or templated content.

```zsh
dsl_text "Hello World" --foreground "green"
dsl_text "{{ .Env.USER }}" --foreground "blue"
```

#### `dsl_path [template] [options...]`
Display current directory path.

```zsh
dsl_path                                    # Default template
dsl_path "({{ .Path }}) " --foreground "cyan" 
```

#### `dsl_git [template] [options...]`
Show git repository information.

```zsh
dsl_git                                     # Full git info
dsl_git "{{ .HEAD }}" --foreground "green"  # Just branch name
```

#### `dsl_session [template] [options...]`
Display user/hostname information.

```zsh
dsl_session                                 # Auto SSH detection
dsl_session "({{ .UserName }})" --foreground "blue"
```

#### Language-Specific Segments

```zsh
dsl_python    # Python virtual environment
dsl_node      # Node.js version
dsl_npm       # NPM version
```

#### System Segments

```zsh
dsl_docker    # Docker environment
dsl_time      # Current time
dsl_exit      # Exit code and prompt character
dsl_shell     # Background job count
```

### Options

All segment functions accept these common options:

- `--template <template>` - Custom template string
- `--foreground <color>` - Text color
- `--background <color>` - Background color  
- `--style <style>` - Segment style (plain, powerline, etc.)
- `--condition <condition>` - Show only when condition is true
- `--cache <duration>` - Cache duration

### Color System

#### Predefined Colors

The DSL includes a comprehensive Nord-based color palette:

```zsh
# Basic colors
black, white, gray, red, green, blue, cyan, yellow, orange, purple

# Semantic colors  
success, warning, error, info, subtle, primary

# Nord theme colors
teal, dark_blue, bright_white, etc.
```

#### Custom Colors

```zsh
dsl_add_color "brand" "#FF6B6B"
dsl_add_color "accent" "#4ECDC4"

dsl_text "My Brand" --foreground "brand"
```

#### Color Helper

```zsh
dsl_color "red"      # Returns "#BF616A"
dsl_color "#FF0000"  # Returns "#FF0000" (pass-through)
```

### Template Helpers

#### Conditional Helpers

```zsh
dsl_if ".Env.SSH_CLIENT"           # {{ if .Env.SSH_CLIENT }}
dsl_endif                          # {{ end }}
dsl_when <condition> <content>     # {{ if condition }}content{{ end }}
dsl_unless <condition> <content>   # {{ if not condition }}content{{ end }}
```

#### Environment Helpers

```zsh
dsl_env "HOME"                     # .Env.HOME
dsl_if_ssh <content>               # Show only in SSH
dsl_if_docker <content>            # Show only when Docker enabled
dsl_if_git <content>               # Show only in git repos
dsl_if_venv <content>              # Show only in Python venv
```

#### Logic Helpers

```zsh
dsl_and <condition1> <condition2>  # and condition1 condition2
dsl_or <condition1> <condition2>   # or condition1 condition2  
dsl_not <condition>                # not condition
```

### Styling Helpers

#### Text Decoration

```zsh
dsl_with_icon "🎯" "Target"        # 🎯 Target
dsl_wrap "(" "content" ")"         # (content)
dsl_parentheses "content"          # (content)
dsl_brackets "content"             # [content]
dsl_braces "content"               # {content}
```

## 📖 Examples

### Simple Theme

```zsh
#!/usr/bin/env zsh
source bourgie-dsl.zsh
dsl_init

dsl_block
dsl_path "{{ .Path }} " --foreground "cyan"
dsl_git "$(dsl_if_git "({{ .HEAD }}) ")" --foreground "green"  
dsl_text "❯ " --foreground "blue"

dsl_compile "simple.yaml"
```

### Advanced Multi-Line Theme

```zsh
#!/usr/bin/env zsh
source bourgie-dsl.zsh
dsl_init

# Custom colors
dsl_add_color "brand" "#FF6B6B"

# Main info line
dsl_block "prompt" "left"
dsl_session "$(dsl_if_ssh "({{ .Env.USER }}@{{ .Env.HOSTNAME }}) ")" --foreground "subtle"
dsl_path "({{ .Path }}) " --foreground "cyan"
dsl_docker "$(dsl_if_docker "$(dsl_with_icon "🐳" "{{ .Env.DOCKER_HOST }}") ")" --foreground "blue"
dsl_python "$(dsl_if_venv "$(dsl_parentheses "{{ .Venv }}") ")" --foreground "yellow"

# Git info line
dsl_newline
dsl_block "prompt" "left"
dsl_git "$(dsl_if_git "$(dsl_with_icon "🌿" "{{ .HEAD }}") {{ if .Working.Changed }}📝{{ end }}{{ if .Staging.Changed }}📦{{ end }} ")" --foreground "green"

# Command line
dsl_newline  
dsl_block "prompt" "left"
dsl_shell "{{ if gt .JobCount 0 }}$(dsl_brackets "{{ .JobCount }}") {{ end }}" --foreground "yellow"
dsl_exit "{{ if .Root }}# {{ else }}❯ {{ end }}" --foreground "brand"

# Right prompt
dsl_rprompt
dsl_time "$(dsl_when ".Env.BOURGIE_SHOW_TIME" "{{ .CurrentDate | date .Format }}")" --foreground "subtle"

dsl_compile "advanced.yaml"
```

### Conditional Segments

```zsh
# Show different content based on environment
dsl_text "$(
    dsl_when ".Env.PRODUCTION" "$(dsl_with_icon "🚨" "PROD")"
    dsl_when ".Env.STAGING" "$(dsl_with_icon "🔧" "STAGE")" 
    dsl_when ".Env.DEVELOPMENT" "$(dsl_with_icon "💻" "DEV")"
)" --foreground "warning"

# Complex git status
dsl_git "$(dsl_if_git "
    $(dsl_with_icon "🌿" "{{ .HEAD }}")
    {{ if .Working.Changed }}$(dsl_with_icon "📝" "{{ .Working.Changed }}"){{ end }}
    {{ if .Staging.Changed }}$(dsl_with_icon "📦" "{{ .Staging.Changed }}"){{ end }}
    {{ if .Upstream }}$(dsl_brackets "{{ .Upstream }}{{ if .Behind }}↓{{ .Behind }}{{ end }}{{ if .Ahead }}↑{{ .Ahead }}{{ end }}"){{ end }}
")" --foreground "white"
```

## 🔧 Integration with Bourgie Plugin

The DSL integrates seamlessly with the existing Bourgie plugin:

```zsh
# In your .zshrc or plugin file
export BOURGIE_USE_DSL=true
export BOURGIE_DSL_FILE="$HOME/.config/bourgie/my-theme.dsl"

# The plugin will automatically compile and use the DSL theme
```

## 🛠️ Development

### Adding New Segment Types

```zsh
function dsl_my_segment() {
    local template="$1"
    [[ -z "$template" ]] && template='{{ .MyField }}'
    shift
    dsl_segment "my_segment" --template "$template" \
        --my_property "value" \
        "$@"
}
```

### Custom Template Functions

```zsh
function dsl_my_helper() {
    local content="$1"
    echo "$(dsl_wrap "<<<" "$content" ">>>")"
}
```

## 📋 Best Practices

1. **Start Simple** - Begin with basic segments and add complexity gradually
2. **Use Semantic Colors** - Prefer named colors over hex values for maintainability
3. **Leverage Conditionals** - Use environment-based conditions for dynamic prompts
4. **Modular Design** - Break complex prompts into multiple blocks
5. **Test Compilation** - Always validate your DSL before deploying
6. **Document Custom Colors** - Comment your color choices for team clarity

## 🐛 Troubleshooting

### Common Issues

1. **Compilation Errors** - Check template syntax and color references
2. **Missing Segments** - Ensure `dsl_init` is called before defining segments
3. **Color Issues** - Verify custom colors are defined before use
4. **Template Syntax** - Use proper Go template syntax in custom templates

### Debug Mode

```zsh
export RAD_BOURGIE_DEBUG=true
source bourgie-dsl.zsh
# DSL operations will now log debug information
```

## 🎨 Theme Gallery

See the `examples/` directory for complete theme examples:

- `simple-theme.dsl` - Minimal single-line prompt
- `bourgie-theme.dsl` - Full-featured Bourgie theme recreation  
- `advanced-theme.dsl` - Complex multi-line theme with custom elements

---

The Bourgie DSL makes creating beautiful, functional oh-my-posh themes as natural as writing shell functions. Focus on your prompt's logic and appearance rather than YAML syntax details.