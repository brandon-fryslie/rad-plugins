bindkey '^[D' zaw-rad-dev

#### zaw source for interacting with rad-shell plugins

### key binding: option + shift + D

function test-zaw-rad-dev() {
  local results="$(find ${ZGEN_DIR} -wholename '*plugin.zsh' -not -path "*/*oh-my-zsh*/*" -not -path "*/*zsh-users*/*" -not -path "*/*prezto*/*"  -not -path "*/*zsh-syntax-highlighting*/*")"
  desc="$(echo "$results" | perl -ne 'printf("%-30s %-20s %-20s\n", $1, $3, $2) if m#^(?:.*/\.zgen(?:om)?/)([\w.-]+/[\w.-]+)/(?:([^/]+)/)?([^/]+)/[^/]+\.zsh$#g')"
  echo "desc ----"
  echo $desc
  echo "/ desc ----"
}

### Use this to view docs, edit a plugin, or view the source code of a plugin
function zaw-src-rad-dev() {
    # Force all zaw variables to be indexed arrays (fixes "bad set of key/value pairs" error)
    # This is needed because something in the environment declares these as associative arrays
    typeset -a candidates cand_descriptions actions act_descriptions options
    typeset -a ignores=()
    if [[ -n $RAD_DEV_IGNORE_BASE_PLUGINS ]]; then
      ignores=(-not -path "*/*oh-my-zsh*/*" -not -path "*/*zsh-users*/*" -not -path "*/*prezto*/*"  -not -path "*/*zsh-syntax-highlighting*/*")
    else
#      echo "seting ignores to be empty"
      ignores=()
    fi
#    echo $ignores

    local results="$(find ${ZGEN_DIR} -wholename '*plugin.zsh' ${ignores[@]})"
    echo $results | wc -l

    local title=$(printf '%-40s %-20s' "Repo" "Plugin")
    typeset -a desc
    # Determine the path and set the description
    desc="$(echo "$results" | perl -ne 'printf("%-40s %-20s\n", $1, $2) if m#^(?:.*/\.zgen(?:om)?/)([\w.-]+/[\w.-]+)/(?:([^/]+)/)?([^/]+)/[^/]+\.zsh$#g')"
    echo $desc | wc -l

    candidates=("${(f)results}")
    cand_descriptions=("${(f)desc}")
    actions=(
        zaw-src-dev-doc
        zaw-src-dev-cd
        zaw-src-dev-edit_file
        zaw-src-dev-cd_edit_repo
        zaw-src-dev-print
        zaw-rad-append-to-buffer
    )
    act_descriptions=(
        "doc"
        "cd"
        "edit file"
        "cd + edit repo"
        "print source"
        "append to buffer"
    )
    options=(-t "$title" -m)
}

# Helper functions
# Get the plugin directory from the filename
zaw-rad-dev-get-plugin-dir() {
  # TODO: fix this
  if [[ -n RAD_SHELL_RAD_PLUGIN_DIR ]]; then
    echo "${RAD_SHELL_RAD_PLUGIN_DIR}"
  else
    echo $1 | perl -pe 's#^(.*/.(?:zgenom|zgen)/[^/]+?/[^/]+?)/.*#\1#'
  fi
}

### zaw-src-dev-format-docs - formats & highlights the documentation in rad-shell plugins
### Prints docs for the plugin and included files
### Usage: rad-print-plugin-docs full-path-to-plugin
### Usage: opt + shift + D -> Enter plugin name -> Press enter to view docs
function rad-print-plugin-docs() {
  local included_files=($(cat $1 | grep 'source' | sed 's#^\(.*\)source "${0:a:h}/\(.*\)"$#\2#' | tr '\n' ' '))
  local plugin_dir="$(dirname $1)"

  rad-print-plugin-docs-single-file $1

  for f in $included_files; do
    echo
    echo
    rad-bold "Included: $(rad-cyan $f)"
    rad-bold '-----'
    rad-print-plugin-docs-single-file $plugin_dir/$f
  done
}

function rad-print-plugin-docs-single-file() {
  cat $1 \
    | grep '^###\|^$' \
    | sed '/^$/N;/^\n$/D' \
    | sed '/./,$!d' \
    | perl -e "$(cat <<'EOF'
use strict; use warnings;

sub colorize { my ($code, @str) = @_; return "\033[0;"."$code"."m".join(' ', @str)."\033[0m"; }
sub bold { colorize('1', @_); }
sub red { colorize('31', @_); }
sub green { colorize(32, @_); }
sub yellow { colorize(33, @_); }
sub magenta { colorize(35, @_); }
sub cyan { colorize(36, @_); }

while(<>) {
  # Command / alias definition
  if (m/^###\s*(.*?) - (.+)$/) {
    print cyan("\n$1\t").yellow("$2\n");
  # Command / alias example
  } elsif (m/^###\s*Example: (.*)$/) {
    print magenta("\tExample: ").green("$1\n");
  # Any other line
  } elsif (m/^###\s+(.*)$/) {
    print yellow("\t$1\n");
  # Heading line
  } elsif (m/^####\s+(.*)$/) {
    print bold("$1\n");
  # Empty line
  } elsif (m/^$/) {
    print "\n";
  }
}
EOF
)"
}

### rad-log-tail - tail the rad-shell log located @ /tmp/zaw.log
function rad-log-tail() {
  local file=/tmp/zaw.log
  touch $file
  tail -f $file
}

### rad-zaw-log - print a message to the rad-shell log @ /tmp/zaw.log
function rad-zaw-log() {
  local file=/tmp/zaw.log
  echo $@ >> $file
}

# Command functions
function zaw-src-dev-doc() {
    BUFFER="rad-print-plugin-docs $1"
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
