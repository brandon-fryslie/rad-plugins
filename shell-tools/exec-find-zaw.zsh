bindkey '^[E' zaw-rad-exec-find

#### zaw source for the 'exec-find' command

### exec-find - find all executable files in the current directory
### Press 'enter' or 'tab' to choose an action

### key binding: option + shift + E

### action run: run executable
### action cd + run: change to directory and run executable
### action cd + edit file: change to directory and edit file
### action cd to repo + edit repo: change to repo directory and edit repo
### action append to buffer: append file path to buffer
function zaw-src-rad-exec-find() {
    local title="executable files"
    candidates=( ${(f)"$(find . -perm -u=x -not -path "./.*/*" -type f)"} )
    : ${(A)cand_descriptions::=$candidates}

    actions=(\
      zaw-rad-exec-find-run \
      zaw-rad-exec-find-cd-run \
      zaw-rad-exec-find-cd-edit-file \
      zaw-rad-exec-find-cd-edit-repo \
      zaw-rad-append-to-buffer \
    )
    act_descriptions=(\
      "run" \
      "cd + run" \
      "cd + edit file" \
      "cd to repo + edit repo" \
      "append to buffer"  \
     )
    options=(-t "$title" -k)
}

function zaw-rad-exec-find-run() {
    zaw-rad-buffer-action "$1"
}

function zaw-rad-exec-find-cd-run() {
    local dir=${(q)$(dirname "$1")} file=${(q)$(basename "$1")}
    zaw-rad-buffer-action "cd ${dir} && ./${file}"
}

function zaw-rad-exec-find-cd-edit-file() {
    local dir=${(q)$(dirname "$1")} file=${(q)$(basename "$1")}
    zaw-rad-buffer-action "cd ${dir} && ${VISUAL:-${EDITOR:-vi}} ${file}"
}

function zaw-rad-exec-find-cd-edit-repo() {
    local repo_dir="$(git rev-parse --show-toplevel)"
    zaw-rad-buffer-action "cd \"$repo_dir\" && ${VISUAL:-${EDITOR:-vi}} \"$repo_dir\""
}

zaw-register-src -n rad-exec-find zaw-src-rad-exec-find
