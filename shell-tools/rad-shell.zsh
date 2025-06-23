
# rad-shell zsh plugin
#
# - It's a zsh plugin in a single file.  Just print the entire file contents as one copyable block
# - it is an interactive plugin installer, similar to homebrew, except for zsh plugins
# - command name: `rad-shell`
# - commands: install, uninstall, list, search, info
# - installed plugins are stored in a file called .rad-plugins in ~
# - for now, we will focus ONLY on 'search' functionality.  Stub out the other commands
# - use idiomatic and standard modern zsh option parsing.  All code should be commercial / production quality and robust
# - there is a configuration file that contains some options.  there is an option that contains a list URLs from which we will load the list of available plugins to install
# - `rad-shell search <plugin name>` will search all URLs in the list of 'plugin sources'
# - the plugin sources are in this format: https://github.com/unixorn/awesome-zsh-plugins.  When rad-shell search is first executed, it will load the content of the plugin sources and cache the result.  Subsequent calls will use this cached result.  Note there can be more than one plugin source
# - the available plugins are parsed out of the fetched data and presented to the user in an interactive list.  Currently installed plugins will be visually distinguished
# - the user can navigate the list with the arrow keys
# - pressing return will install the plugin that is selected
# - please implement this plugin now

# shell-tools/plugin-source-example.md contains a sample of the content that will be fetched from a plugin source.  Keep in mind that t
# here will be content in the plugin source that does NOT match this format, and that content must be ignored.  The format of the plugi
# ns in the document will be as follows: - [arduino](https://github.com/raghur/zsh-arduino) - Adds scripts to build, upload and monitor
#  arduino sketches from a command line. Requires [`jq`](https://stedolan.github.io/jq/).
#
# this format generalized is this:
#
# <beginning of line>- [<plugin name>](<url to plugin repo>) - <plugin description><end of line>
# we should display the plugin name and the description to the user.  If the user selects the plugin, we will use the plugin url to ins
# tall the plugin (do not install the plugin yet, just stub that part out)shell-tools/plugin-source-example.md contains a sample of the content that will be fetched from a plugin source.  Keep in mind that t
# here will be content in the plugin source that does NOT match this format, and that content must be ignored.  The format of the plugi
# ns in the document will be as follows: - [arduino](https://github.com/raghur/zsh-arduino) - Adds scripts to build, upload and monitor
#  arduino sketches from a command line. Requires [`jq`](https://stedolan.github.io/jq/).
#
# this format generalized is this:
#
# <beginning of line>- [<plugin name>](<url to plugin repo>) - <plugin description><end of line>
# we should display the plugin name and the description to the user.  If the user selects the plugin, we will use the plugin url to ins
# tall the plugin (do not install the plugin yet, just stub that part out)

# Define cache and configuration file paths
RAD_CACHE_FILE="${HOME}/.rad-plugin-cache"
RAD_CONFIG_FILE="${HOME}/.radrc"
RAD_PLUGIN_FILE="${HOME}/.rad-plugins"
# Default source list – used if user config is missing/empty
RAD_DEFAULT_SOURCES=(
  "https://raw.githubusercontent.com/unixorn/awesome-zsh-plugins/master/README.md"
)
_rad_log() {
  print -P "%F{blue}[rad-shell]%f $*"
}

_rad_error() {
  print -P "%F{red}[rad-shell ERROR]%f $*" >&2
}

# Load configuration and cache
_rad_load_config() {
  PLUGIN_SOURCES=()                        # reset
  [[ -f $RAD_CONFIG_FILE ]] && source "$RAD_CONFIG_FILE"
  [[ ${#PLUGIN_SOURCES[@]} -eq 0 ]] && PLUGIN_SOURCES=("${RAD_DEFAULT_SOURCES[@]}")
}

_rad_load_installed_plugins() {
  if [[ -f "$RAD_PLUGIN_FILE" ]]; then
    INSTALLED_PLUGINS=("${(@f)$(<"$RAD_PLUGIN_FILE")}")
  else
    INSTALLED_PLUGINS=()
  fi
}

_rad_fetch_plugin_data() {
  _rad_log "Fetching plugin lists from sources..."
  local content url
  : > "$RAD_CACHE_FILE"
  for url in "${PLUGIN_SOURCES[@]}"; do
    content="$(curl -fsSL "$url" 2>/dev/null)"
    if [[ -n "$content" ]]; then
      print -r -- "$content" >> "$RAD_CACHE_FILE"
    else
      _rad_error "Failed to fetch plugin source: $url"
    fi
  done
}

_rad_parse_plugins_from_cache() {
  # Prefer gawk for its nicer sub-match support
  if command -v gawk >/dev/null 2>&1; then
    gawk '
      /^\- \[.*\]\(https:\/\/github.com\/[^)]+\) - / {
        match($0, /^\- \[([^]]+)\]\((https:\/\/github.com\/[^)]+)\) - (.*)$/, a)
        if (a[1] && a[2]) print a[1] "\t" a[2] "\t" a[3]
      }' "$RAD_CACHE_FILE" | sort -u
  else
    # Portable variant that works with plain POSIX/BSD awk
    awk '
      /^\- \[.*\]\(https:\/\/github.com\/[^)]+\) - / {
        line = $0
        sub(/^- \[/, "", line)                 # drop leading "- ["
        split(line, p1, "\\]\\(")              # p1[1]=name, p1[2]=url+) - desc
        name = p1[1]
        split(p1[2], p2, "\\) - ")             # p2[1]=url, p2[2]=desc
        url  = p2[1]
        desc = p2[2]
        if (name && url) print name "\t" url "\t" desc
      }' "$RAD_CACHE_FILE" | sort -u
  fi
}

_rad_init_keymap() {
  zmodload zsh/zle
  zmodload zsh/terminfo || {
    _rad_error "Failed to load terminfo. Ensure your terminal supports terminfo."
    return 1
  }

  if [[ -z $terminfo[kcuu1] || -z $terminfo[kcud1] ]]; then
    _rad_error "Terminal does not support required key sequences for navigation."
    return 1
  fi

  zle -N rad-interactive-up _rad_interactive_up
  zle -N rad-interactive-down _rad_interactive_down
  zle -N rad-interactive-enter _rad_interactive_enter
  zle -N rad-interactive-exit _rad_interactive_exit

  bindkey -M rad-interactive $terminfo[kcuu1] rad-interactive-up
  bindkey -M rad-interactive $terminfo[kcud1] rad-interactive-down
  bindkey -M rad-interactive $'\n' rad-interactive-enter
  bindkey -M rad-interactive $'\x1b' rad-interactive-exit
  bindkey -M rad-interactive q rad-interactive-exit
}

_rad_interactive_up() {
  (( selected > 0 )) && (( selected-- ))
  _render
}

_rad_interactive_down() {
  (( selected < total - 1 )) && (( selected++ ))
  _render
}

_rad_interactive_enter() {
  local entry="${plugins[selected + 1]}"
  local plugin_url="${entry[(w)3]}"
  _rad_log "Stub: Installing plugin from $plugin_url"
  # Stub: Add installation logic here
  zle -M "Installing plugin from $plugin_url"
  zle -K main
}

_rad_interactive_exit() {
  zle -K main
}

_rad_interactive_mode() {
  local plugins selected total entry fields plugin_name plugin_url plugin_desc
  plugins=("${(@f)$(_rad_parse_plugins_from_cache)}")
  total=${#plugins}
  (( total == 0 )) && { _rad_error "No plugins found."; return 1; }
  selected=0

  _clear()      { printf '\e[H\e[2J'; }
  _highlight()  { print -Pn "%F{green}$1%f"; }
  _installed()  { print -Pn "%F{242}$1 (installed)%f"; }

  _render() {
    _clear
    print -P "%F{blue}rad-shell:%f Select plugin (↑/↓, <enter> install, q quit)"
    for i in {1..$#plugins}; do
      entry="$plugins[$i]"
      fields=("${(@s:\t:)entry}")
      plugin_name="$fields[1]"
      plugin_desc="$fields[3]"
      if (( i == selected + 1 )); then
        print -P "➤ %F{green}$plugin_name%f - $plugin_desc"
      elif [[ "${INSTALLED_PLUGINS[(r)$plugin_name]}" == "$plugin_name" ]]; then
        print -P "  %F{242}$plugin_name (installed)%f"
      else
        print -P "  $plugin_name - $plugin_desc"
      fi
    done
  }

  _render
  local key rest
  while true; do
    read -rs -k1 key                               # read one char
    if [[ $key == $'\x1b' ]]; then                 # arrow prefix
      read -rs -k2 rest
      key+=$rest
    fi
    case $key in
      $'\e[A') (( selected > 0 )) && (( selected-- )) ;;          # up
      $'\e[B') (( selected < total - 1 )) && (( selected++ )) ;;  # down
      '')     # <enter>
        entry="${plugins[selected + 1]}"
        fields=("${(@s:\t:)entry}")
        plugin_name="$fields[1]"
        plugin_url="$fields[2]"
        _rad_log "Stub: Installing plugin '$plugin_name' from $plugin_url"
        break ;;
      q|$'\e') break ;;                                           # quit
    esac
    _render
  done
  _clear
}

rad-shell() {
  emulate -L zsh
  setopt extended_glob

  local cmd args
  if [[ $# -lt 1 ]]; then
    _rad_error "Usage: rad-shell <command> [...]"
    return 1
  fi

  cmd="$1"; shift
  args=("$@")

  _rad_load_config
  _rad_load_installed_plugins

  case $cmd in
    install)
      _rad_error "'install' is not yet implemented."
      ;;
    uninstall)
      _rad_error "'uninstall' is not yet implemented."
      ;;
    list)
      _rad_error "'list' is not yet implemented."
      ;;
    info)
      _rad_error "'info' is not yet implemented."
      ;;
    search)
      if [[ ! -f "$RAD_CACHE_FILE" || "$RAD_CACHE_FILE" -ot "$RAD_CONFIG_FILE" ]]; then
        _rad_fetch_plugin_data
      fi
      _rad_interactive_mode
      ;;
    *)
      _rad_error "Unknown command: $cmd"
      return 1
      ;;
  esac
}
