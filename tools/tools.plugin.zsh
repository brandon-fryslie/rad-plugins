# Add tools to path

# make path unique
# typeset -U $PATH

tool_add_path() {
  local tool=$1
  local add_path=$2

  command -v ${tool} >/dev/null && export PATH="${PATH}:${add_path}"
}

tool_add_path pnpm "$HOME/node_modules/.bin"

# rust
tool_add_path cargo "$HOME/.cargo/bin"

# python pyenv
# tool_add_path pyenv "$HOME/.pyenv/bin"

# uv
tool_add_path uv "$(uv tool dir)"
