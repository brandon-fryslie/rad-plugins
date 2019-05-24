autoload -U add-zsh-hook
autoload -Uz vcs_info

source "/usr/local/opt/kube-ps1/share/kube-ps1.sh"

setopt promptsubst

zstyle ':vcs_info:*' enable git svn
zstyle ':vcs_info:git*:*' get-revision true
zstyle ':vcs_info:git*:*' check-for-changes true
zstyle ':vcs_info:git*:*' stagedstr "%F{green}S%F{black}%B"
zstyle ':vcs_info:git*:*' unstagedstr "%F{red}U%F{black}%B"
zstyle ':vcs_info:git*+set-message:*' hooks git-st git-stash git-username

zstyle ':vcs_info:git*' formats "(%s) %12.12i %c%u %b%m" # hash changes branch misc
zstyle ':vcs_info:git*' actionformats "(%s|%F{white}%a%F{black}%B) %12.12i %c%u %b%m"

add-zsh-hook precmd theme_precmd

[[ $GITTACULOUS_ENABLE_SSH_THEME == 'true' || -n $SSH_CLIENT ]] && GITTACULOUS_ENABLE_SSH_THEME=true || GITTACULOUS_ENABLE_SSH_THEME=false

# Show remote ref name and number of commits ahead-of or behind
function +vi-git-st() {
    local ahead behind remote
    local -a gitstatus

    # Are we on a remote-tracking branch?
    remote=${$(git rev-parse --verify ${hook_com[branch]}@{upstream} \
        --symbolic-full-name --abbrev-ref 2>/dev/null)}

    if [[ -n ${remote} ]] ; then
        ahead=$(git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l | sed -e 's/^[[:blank:]]*//')
        (( $ahead )) && gitstatus+=( "%F{green}+${ahead}%F{black}%B" )

        behind=$(git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l | sed -e 's/^[[:blank:]]*//')
        (( $behind )) && gitstatus+=( "%F{red}-${behind}%F{black}%B" )

        [[ ${#gitstatus} -gt 0 ]] && gitstatus=" ${(j:/:)gitstatus}"
        hook_com[branch]="${hook_com[branch]} [${remote}${gitstatus}]"
    fi
}

# Show count of stashed changes
function +vi-git-stash() {
    local -a stashes

    if [[ -s ${hook_com[base]}/.git/refs/stash ]] ; then
        stashes=$(git stash list 2>/dev/null | wc -l | sed -e 's/^[[:blank:]]*//')
        hook_com[misc]+=" (${stashes} stashed)"
    fi
}

# Show local git user.name
function +vi-git-username() {
    local -a username

    username=$(git config --local --get user.name | sed -e 's/\(.\{40\}\).*/\1.../')
    hook_com[misc]+=" ($username)"
}

function _get-current-dir-prompt() {
    local infoline
    local dir_color

    # If we're in an SSH client, prepend the user and machine
    if [[ $GITTACULOUS_ENABLE_SSH_THEME == 'true' ]]; then
        # Current dir; show in yellow if not writable
        [[ -w $PWD ]] && dir_color="%F{green}" || dir_color="%F{yellow}"
        infoline="%F{black}%B(%n@%m)%F{default}%b ${dir_color}(${PWD/#$HOME/~})%F{default} "
    else
        # Current dir; show in yellow if not writable
#        [[ -w $PWD ]] && infoline+=( "%F{green}" ) || infoline+=( "%F{yellow}" )
        infoline="(${PWD/#$HOME/~})%F{default} "
    fi

    echo -n "${infoline}"
}

function setprompt() {
    unsetopt shwordsplit
    local -a lines infoline
    local x i filler i_width filler_color

    ### First, assemble the top line
    # Current dir; show in yellow if not writable
    [[ -w $PWD ]] && infoline+=( "%F{green}" ) || infoline+=( "%F{yellow}" )
    infoline+=( "$(_get-current-dir-prompt)" )


    infoline+=( "$(kube_ps1)%F{default}" )


    # Username & host
    [[ $GITTACULOUS_ENABLE_SSH_THEME != 'true' ]] && infoline+=( "%F{black}%B(%n)%F{default}%b" ) || infoline+=( "" )

    i_width=${(S)infoline//(\%F\{*\}|\%b|\%B)} # search-and-replace color escapes
    i_width=${#${(%)i_width}} # expand all escapes and count the chars

    [[ $GITTACULOUS_ENABLE_SSH_THEME == 'true' ]] && filler_color="%F{23}" || filler_color="%F{black}"

    filler="${filler_color}%B${(l:$(( $COLUMNS - $i_width ))::-:)}%F{default}%b"
    infoline[2]=( "${infoline[2]}${filler} " )

    ### Now, assemble all prompt lines
    lines+=( ${(j::)infoline} )
    [[ -n ${vcs_info_msg_0_} ]] && lines+=( "%F{black}%B${vcs_info_msg_0_}%F{default}%b" )
    lines+=( "%(1j.%F{black}%B%j%F{default}%b .)%(0?.%F{white}.%F{red})%#%F{default} " )

    ### Finally, set the prompt
    PROMPT=${(F)lines}
}


theme_precmd () {
    vcs_info
    setprompt
}
