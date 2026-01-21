bindkey '^[>' zaw-rad-docker-container

#### docker container zaw source
###
### provides a filterable list of your docker containers
###
### key: option + shift + >

function zaw-src-rad-docker-container() {
    # Force all zaw variables to be indexed arrays (fixes "bad set of key/value pairs" error)
    # This is needed because something in the environment declares these as associative arrays
    typeset -a candidates cand_descriptions actions act_descriptions options

    local format_string="table {{ .Names }}\\t{{ .Image }}\\t{{ .Status }}\\t{{ .Ports }}\\t{{ .ID }}"
    local docker_ps_results="$(docker ps -a --format $format_string)"
    local title="$(echo $docker_ps_results | head -n 1)"
    local desc="$(echo $docker_ps_results | tail -n +2)"
    local container_name="$(echo $desc | awk '{print $1}')"
    : ${(A)candidates::=${(f)container_name}}
    : ${(A)cand_descriptions::=${(f)desc}}
    actions=(\
        zaw-src-docker-container-logs \
        zaw-src-docker-container-exec \
        zaw-src-docker-container-port \
        zaw-src-docker-container-inspect \
        zaw-src-docker-container-restart \
        zaw-src-docker-container-rm \
        zaw-rad-append-to-buffer \
    )
    act_descriptions=(\
        "logs" \
        "exec" \
        "port" \
        "inspect" \
        "restart" \
        "rm -fv" \
        "append name to buffer" \
    )
    options=(-t "$title" -m)
}

# Helper functions

# Perform buffer action with multiple containers
function zaw-rad-docker-container-multiselect-action() {
    zaw-rad-buffer-action "$1 ${(j: :)selected}"
}

# Command functions

function zaw-src-docker-container-logs() {
    BUFFER="docker logs -f $1"
    zaw-rad-action ${reply[1]}
}

function zaw-src-docker-container-exec() {
    local exec_candidates=(bash env "ps ax")
    local reply=()
    filter-select -k -e select-action -t "select command for exec" -- "${(@)exec_candidates}"
    [[ $? -eq 0 ]] || return $?

    action=${reply[1]}
    exec_command=${reply[2]}

    BUFFER="docker exec -ti $1 $exec_command"
    zle $action
    zle end-of-line
}

function zaw-src-docker-container-port() {
    zaw-rad-buffer-action "docker port $1"
}

function zaw-src-docker-container-inspect() {
    # use jq if we have it
    local jq=''
    type jq > /dev/null && jq="| jq"

    zaw-rad-buffer-action "docker inspect $1 $jq"
}

function zaw-src-docker-container-restart() {
    zaw-rad-buffer-action "docker restart $1"
}

function zaw-src-docker-container-rm() {
    zaw-rad-docker-container-multiselect-action 'docker rm -fv'
}

zaw-register-src -n rad-docker-container zaw-src-rad-docker-container
