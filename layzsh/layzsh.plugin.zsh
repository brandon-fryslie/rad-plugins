
#### lazysh - AI assistant in your shell.  Go on, get lazy

source "${0:a:h}/layzsh-sgpt.zsh"
source "${0:a:h}/layzsh-util.zsh"
source "${0:a:h}/layzsh-zle.zsh"


# Initialize LayZsh state
LAYZSH_ACTIVE=false

# Function to toggle LayZsh state
toggle_layzsh() {
    if $LAYZSH_ACTIVE; then
        LAYZSH_ACTIVE=false
        # Remove the indicator character from the prompt
        PROMPT="${PROMPT//👁️ }"
    else
        LAYZSH_ACTIVE=true
        # Add an indicator character to the prompt
        PROMPT="${PROMPT}👁️ "
    fi
    zle reset-prompt  # Ensure the prompt is updated immediately
}

# Key Bindings Section
# --------------------
# Consolidate all key bindings here for better visibility

# Create ZLE widgets
zle -N toggle_layzsh
zle -N sgpt_zsh_chat
zle -N sgpt_zsh_fix

# Bind the Enter key to the custom accept-line function
bindkey '^M' layzsh_accept_line

# Bind keys to ZLE widgets
bindkey '^[i^[i' toggle_layzsh
bindkey '^[i^[j' sgpt_zsh_chat # Submit a prompt as a chat
bindkey '^[i^[k' sgpt_zsh_fix  # Generate shell commands


