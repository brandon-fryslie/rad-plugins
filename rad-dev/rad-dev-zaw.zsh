bindkey '^[D' zaw-rad-dev

function zaw-src-rad-dev() {
    local format_string="table {{ .Names }}\\t{{ .Image }}\\t{{ .Status }}\\t{{ .Ports }}\\t{{ .Size }}"
    local results="$(find ~/.zgen \( -wholename '*plugin.zsh' -o -wholename '*-zaw-*' \))"

    local title=$(printf '%-40s %-20s' "Repo" "Plugin")
    local desc="$(echo "$results" | perl -ne 'printf("%-40s %-20s\n", $1, $2) if m#^(?:.*/.zgen/)(?:git@[\w+\.-]+COLON-)?([\w\.@-]+/[\w\.-]+?)(?:.git)?(?:-master)?/.*?([\w.-]+\.zsh)$#g')"

    : ${(A)candidates::=${(f)results}}
    : ${(A)cand_descriptions::=${(f)desc}}
    actions=(\
        zaw-src-dev-doc \
        zaw-src-dev-cd \
        zaw-src-dev-edit_file \
        zaw-src-dev-cd_edit_repo \
        zaw-src-dev-print \
        zaw-rad-append-to-buffer \
    )
    act_descriptions=(\
        "doc" \
        "cd" \
        "edit file" \
        "cd + edit repo" \
        "print source" \
        "append to buffer" \
    )
    options=(-t "$title" -m)
}

# Helper functions
# Get the plugin directory from the filename
zaw-rad-dev-get-plugin-dir() {
    echo $1 | perl -pe 's#^(.*/.zgen/[^/]+?/[^/]+?)/.*#\1#'
}

### zaw-src-dev-format-docs - formats & highlights the documentation in rad-shell plugins
function zaw-src-dev-format-docs() {
  cat $1 | grep '^###\|^$' | sed '/^$/N;/^\n$/D' | sed '/./,$!d' | perl -e "$(cat <<'EOF'
  use strict; use warnings;

  sub colorize { my ($code, @str) = @_; return "\033[0;"."$code"."m".join(' ', @str)."\033[0m"; }
  sub bold { colorize('1', @_); }
  sub red { colorize('31', @_); }
  sub green { colorize(32, @_); }
  sub yellow { colorize(33, @_); }
  sub magenta { colorize(35, @_); }
  sub cyan { colorize(36, @_); }

  while(<>) {
    if (m/^###\s*(\w+[\w\s]*) - (.+)$/) {
      print cyan("\n$1\t").yellow("$2\n");
    } elsif (m/^###\s*Example: (.*)$/) {
      print magenta("\tExample: ").green("$1\n");
    } elsif (m/^###\s+(.*)$/) {
      print yellow("\t$1\n");
    } elsif (m/^####\s+(.*)$/) {
      print bold("$1\n");
    } elsif (m/^$/) {
      print "\n";
    }
  }
EOF
)"
}

function rad-log-tail() {
  local file=/tmp/zaw.log
  touch $file
  tail -f $file
}

function rad-zaw-log() {
  local file=/tmp/zaw.log
  echo $@ >> $file
}

# Command functions
function zaw-src-dev-doc() {
    rad-zaw-log "Triggering docs"
    # doc_string="$(cat /Users/brandon.fryslie/.zgen/brandon-fryslie/rad-plugins-master/docker/docker.plugin.zsh | grep '^###' | sed 's/^###//')"

    # rad-zaw-log $doc_string



    BUFFER="zaw-src-dev-format-docs $1"
    zaw-rad-action ${reply[1]}
}

function zaw-src-dev-cd() {
    BUFFER="cd $(zaw-rad-dev-get-plugin-dir $1)"
    zaw-rad-action ${reply[1]}
}

function zaw-src-dev-edit_file() {
    BUFFER="$(rad-get-visual-editor) $1"
    zaw-rad-action ${reply[1]}
}

function zaw-src-dev-cd_edit_repo() {
    local plugin_dir="$(zaw-rad-dev-get-plugin-dir $1)"
    BUFFER="cd $plugin_dir && $(rad-get-visual-editor) $plugin_dir"
    zaw-rad-action ${reply[1]}
}

function zaw-src-dev-print() {
    BUFFER="cat $1"
    zaw-rad-action ${reply[1]}
}


zaw-register-src -n rad-dev zaw-src-rad-dev
