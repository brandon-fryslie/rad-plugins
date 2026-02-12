# Default prompt elements configuration
# Users can override these arrays in their personal config
#
# These defaults provide a minimal, fast prompt with git status.
# Override POWERLEVEL9K_LEFT_PROMPT_ELEMENTS and POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS
# in your personal config to customize.

# Left prompt: directory and git, with prompt char on second line
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  # =========================[ Line #1 ]=========================
  dir                     # current directory
  vcs                     # git status (gitstatus-based)
  # =========================[ Line #2 ]=========================
  newline                 # \n
  prompt_char             # prompt symbol
)

# Right prompt: common developer tools and time
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  # =========================[ Line #1 ]=========================
  status                  # exit code of last command
  command_execution_time  # duration of the last command
  background_jobs         # presence of background jobs
  direnv                  # direnv status
 #
               # python virtual environment
 # pyenv                   # python environment
  goenv                   # go environment
  nodenv                  # node.js version from nodenv
  nvm                     # node.js version from nvm
  nodeenv                 # node.js environment
  kubecontext             # current kubernetes context
  terraform               # terraform workspace
  aws                     # aws profile
  azure                   # azure account name
  context                 # user@hostname
  time                    # current time
  # =========================[ Line #2 ]=========================
  newline                 # \n
)
