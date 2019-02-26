bindkey '^[E' zaw-rad-exec-find

#### zaw source for the 'proj' command

### proj - allows you to easily navigate your projects
### brings up a filterable list of directories in PROJECT_DIR
### set the PROJECT_DIR environment variable to use proj
### Press 'enter' or 'tab' to choose an action

### key binding: option + shift + E

### action cd: change to directory
### action cd + edit: change to directory and open in your defined editor
### action open on github: open the repo on github
function zaw-src-rad-exec-find() {
    local title="executable files"
    : ${(A)candidates::=$(find . -perm -u=x -not -path "./.*/*" -type f)}
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
    zaw-rad-buffer-action "cd $(dirname $1) && ./$(basename $1)"
}

function zaw-rad-exec-find-cd-edit-file() {
    zaw-rad-buffer-action "cd $(dirname $1) && ${VISUAL:-${EDITOR:-vi}} $(basename $1)"
}

function zaw-rad-exec-find-cd-edit-repo() {
    local repo_dir="$(git rev-parse --show-toplevel)"
    zaw-rad-buffer-action "cd $repo_dir && ${VISUAL:-${EDITOR:-vi}} $repo_dir"
}

zaw-register-src -n rad-exec-find zaw-src-rad-exec-find
