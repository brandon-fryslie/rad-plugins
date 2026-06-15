function zaw-rad-git-status-get-candidates() {
    git rev-parse --git-dir >/dev/null 2>&1
    [[ $? == 0 ]] || return $?
    local file_list="$(git status --porcelain)"

    # [LAW:no-silent-failure] Use -z (NUL-delimited) to handle paths with spaces and renames.
    # Each entry is "XY path"; rename old-paths have no XY prefix and are skipped.
    local -a raw_cands cand_paths
    raw_cands=("${(@0)$(git status --porcelain -z)}")
    local cand
    for cand in "${raw_cands[@]}"; do
        [[ "${cand:0:2}" =~ [A-Z?!\ ][A-Z?!\ ] ]] && cand_paths+=("${cand:3}")
    done

    : ${(A)filter_select_candidates::=${cand_paths}}

    : ${(A)filter_select_descriptions::=${${(f)${file_list}}/ M /[modified]        }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/AM /[add|modified]    }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/MM /[staged|modified] }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/M  /[staged]          }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/A  /[staged(add)]     }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/ D /[deleted]         }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/UU /[conflict]        }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/AA /[conflict]        }}
    : ${(A)filter_select_descriptions::=${${(M)filter_select_descriptions}/\?\? /[untracked]       }}

    # echo "rad-git-status getting candidates: ${(j:,:)filter_select_candidates}" >> /tmp/zaw.log
}

function zaw-rad-git-status() {
    zaw-rad-git-status-get-candidates

    while true; do
        zaw-rad-git-status-get-candidates
        filter-select -f zaw-rad-git-status-get-candidates -m -M radgit -d filter_select_descriptions -e select-action -t "select file" -- "${(@)filter_select_candidates}"

        local action="${reply[1]}"

        [[ $action == 'select-action' ]] && break
    done

    BUFFER="git status"
    zaw-rad-action "${reply[1]}"
}

function rad-git-stage {
    git add "${FILTER_SELECT_SELECTED}"
}

zle -N rad-git-stage

function rad-git-unstage {
    git reset "${FILTER_SELECT_SELECTED}"
}

zle -N rad-git-unstage

function rad-git-stage-all {
    git add .
}

zle -N rad-git-stage-all

function rad-git-unstage-all {
    git reset .
}

zle -N rad-git-unstage-all

function _rad-git-init-keymap() {
    integer fd ret

    # be quiet and check filterselect keybind defined
    exec {fd}>&2 2>/dev/null
    bindkey -l radgit > /dev/null
    ret=$?
    exec 2>&${fd} {fd}>&-

    if (( ret != 0 )); then
        bindkey -N radgit
        bindkey -M radgit '^S' rad-git-stage
        bindkey -M radgit '^D' rad-git-unstage
        bindkey -M radgit '^[s' rad-git-stage-all
        bindkey -M radgit '^[d' rad-git-unstage-all
        bindkey -M radgit '^[d' rad-git-unstage-all
    fi
}

_rad-git-init-keymap
