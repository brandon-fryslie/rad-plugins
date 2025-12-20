# rad-p10k: Opinionated Powerlevel10k Configuration
#
# A modular, shareable p10k configuration with sensible defaults.
# Provides a complete, beautiful prompt out of the box while allowing
# users to override specific settings in their personal config.
#
# Usage:
#   1. Source this plugin before your personal p10k config
#   2. Override any settings in your personal config (e.g., POWERLEVEL9K_LEFT_PROMPT_ELEMENTS)
#
# Features:
#   - Modern prompt styling with nerdfont icons
#   - Custom git formatter with detailed status info
#   - Transient prompt support
#   - Comprehensive segment configurations
#
# Dependencies:
#   - powerlevel10k (romkatv/powerlevel10k)

# Capture plugin directory
typeset -g RAD_P10K_PLUGIN_DIR="${0:A:h}"

# Load configuration modules in order
# Users can override any setting after sourcing this plugin
function rad-p10k-init() {
  emulate -L zsh -o extended_glob

  local config_dir="${RAD_P10K_PLUGIN_DIR}/config"

  # Source all config files in order
  for f in "$config_dir"/*.zsh(N); do
    source "$f"
  done
}

# Initialize rad-p10k
rad-p10k-init
