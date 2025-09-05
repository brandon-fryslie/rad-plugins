# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains Zsh plugins for the rad-shell framework. The rad-shell framework is a feature-rich shell environment built on Zsh, Prezto, and Zgenom (a fork of Zgen). These plugins provide additional functionality and features for the shell environment.

## Key Concepts

1. **Plugin Structure**: Each plugin is contained in its own directory and typically has a main plugin file named `[plugin-name].plugin.zsh`. Some plugins also have additional supporting files.

2. **Plugin Initialization**: Plugins are loaded by the rad-shell framework through the `~/.rad-plugins` file. Plugins can register initialization hooks using the `rad_plugin_init_hooks+=("hook_name:${script_dir}")` pattern.

3. **Zaw Integration**: Several plugins integrate with Zaw, which provides filterable lists for various data sources (similar to Helm in Emacs).

4. **Shared Utilities**: Common functions are available through the `init-plugin` module, providing utilities for color output, path manipulation, and other shared functionality.

## Common Development Tasks

### Testing Plugin Changes

When modifying a plugin, you can test your changes by:

```bash
# Source the modified plugin file directly
source /path/to/plugin/plugin-name.plugin.zsh

# Or reload your entire Zsh configuration
source ~/.zshrc
```

### Creating a New Plugin

To create a new plugin:

1. Create a new directory for your plugin: `mkdir my-plugin`
2. Create the main plugin file: `touch my-plugin/my-plugin.plugin.zsh`
3. Implement your plugin functionality
4. Add your plugin to ~/.rad-plugins: `echo "brandon-fryslie/rad-plugins my-plugin" >> ~/.rad-plugins`
5. Open a new terminal or run `source ~/.zshrc`

### Adding a Plugin Feature

When adding new features to existing plugins:

1. Follow the existing coding style and patterns
2. Use the rad-shell utility functions where appropriate
3. For Zaw integrations, look at existing `*-zaw.zsh` files as examples

## Important Files and Directories

- `plugin-shared/plugin-shared.plugin.zsh`: Contains shared utilities (though marked as deprecated)
- `init-plugin/init-plugin.plugin.zsh`: Core initialization functions for rad-shell
- `*.plugin.zsh`: Main entry point for each plugin
- `*-zaw.zsh`: Zaw integration files for filterable command lists

## Coding Standards

1. Prefix shared functions with `rad-` to avoid namespace conflicts
2. Use descriptive comments for function documentation
3. Follow the existing code style in the repository
4. Use Zsh idioms and features where appropriate