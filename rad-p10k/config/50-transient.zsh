# Transient Prompt Configuration
# Settings and helper functions for transient prompt behavior

# Transient prompt mode:
#   - off:      Don't change prompt when accepting a command line.
#   - always:   Trim down prompt when accepting a command line.
#   - same-dir: Trim down prompt when accepting a command line unless this is the first command
#               typed after changing current working directory.
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=same-dir

# Glob patterns for controlling which segments to show/hide in transient mode
# These can be overridden in personal config
typeset -g RAD_TRANSIENT_GLOB_HIDE='1|2|3/left_frame|3/left/*'
typeset -g RAD_TRANSIENT_GLOB_SHOW='*/newline|3/left/(time|status)'

# Variables to backup and restore for transient prompt
# This makes transient prompt configuration simpler
typeset -ga RAD_TRANSIENT_VARS=(
  POWERLEVEL9K_PROMPT_CHAR_BACKGROUND
  POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL
  POWERLEVEL9K_PROMPT_CHAR_LEFT_PROMPT_FIRST_SEGMENT_START_SYMBOL
  POWERLEVEL9K_PROMPT_CHAR_LEFT_LEFT_WHITESPACE
  POWERLEVEL9K_PROMPT_CHAR_LEFT_RIGHT_WHITESPACE
)

# Storage for original values
typeset -gA _RAD_P10K_ORIG_VALUES

# Call this when entering transient mode to save original values
function rad-p10k-set-transient-on() {
  for var in "${RAD_TRANSIENT_VARS[@]}"; do
    _RAD_P10K_ORIG_VALUES[$var]="${(P)var}"
  done
}

# Call this when exiting transient mode to restore original values
function rad-p10k-set-transient-off() {
  for var in "${RAD_TRANSIENT_VARS[@]}"; do
    if [[ -v "_RAD_P10K_ORIG_VALUES[$var]" ]]; then
      if [[ ${(t)${(P)var}} == "array" ]]; then
        eval "${var}=(\${_RAD_P10K_ORIG_VALUES[$var]})"
      else
        typeset -g "$var=${_RAD_P10K_ORIG_VALUES[$var]}"
      fi
    fi
  done
}
