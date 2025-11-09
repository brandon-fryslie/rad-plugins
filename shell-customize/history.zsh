## Command history configuration
## Copied & modified from oh-my-zsh history plugin
HISTFILE=$HOME/.zsh_history

HISTSIZE=10000
SAVEHIST=10000

# Show history
case $HIST_STAMPS in
  "mm/dd/yyyy") alias history='fc -fl 1' ;;
  "dd.mm.yyyy") alias history='fc -El 1' ;;
  "yyyy-mm-dd") alias history='fc -il 1' ;;
  *) alias history='fc -l 1' ;;
esac

set -o append_history
set -o extended_history
set -o hist_expire_dups_first
set -o hist_ignore_all_dups
set -o hist_ignore_space
set -o hist_reduce_blanks
set -o hist_verify
set +o inc_append_history # Apparently this should be off if share_history is turned on
set -o share_history
