set +o noclobber # Allow overwriting of files by redirection (many scripts assume this behavior)

# Just so we have something
export EDITOR=vi

[[ -f "${0:a:h}/history.zsh" ]] && source "${0:a:h}/history.zsh"
[[ -f "${0:a:h}/styles.zsh" ]] && source "${0:a:h}/styles.zsh"
