bindkey '^[P' zaw-rad-proj

#### zaw source for the 'proj' command

### proj - allows you to easily navigate your projects
### brings up a filterable list of directories in PROJECT_DIR
### set the PROJECT_DIR environment variable to use proj
### Press 'enter' or 'tab' to choose an action

### key binding: option + shift + P

### action cd: change to directory
### action cd + edit: change to directory and open in your defined editor
### action open on github: open the repo on github
function zaw-src-rad-proj() {
    local title="projects"
    : ${(A)candidates::=$(cd "$PROJECTS_DIR" && ls -d */ | sed 's/\///g')}
    : ${(A)cand_descriptions::=$candidates}

    actions=(\
      zaw-rad-proj-cd \
      zaw-rad-proj-cd-edit \
      zaw-rad-proj-github-open \
      zaw-rad-append-to-buffer \
    )
    act_descriptions=(\
      "cd" \
      "cd + edit" \
      "open on github" \
      "append to buffer"  \
     )
    options=(-t "$title" -k)
}

function zaw-rad-proj-cd() {
    zaw-rad-buffer-action "proj $1"
}

function zaw-rad-proj-cd-edit() {
    zaw-rad-buffer-action "proj $1 && ${VISUAL:-${EDITOR:-vi}} ."
}

function zaw-rad-proj-github-open() {
    zaw-rad-buffer-action "gh-open origin $PROJECTS_DIR/$1"
}

zaw-register-src -n rad-proj zaw-src-rad-proj
