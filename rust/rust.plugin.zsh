


# Set standard Rust environment variables
export RUST_BACKTRACE="1"

# Auto-load completions if available
if [[ -d "$HOME/.zfunc" ]]; then
  fpath+=("$HOME/.zfunc")
  compinit
fi

# Rustup completions setup
if command -v rustup &>/dev/null; then
  # Generate completions if they don't exist
  if [[ ! -d "$HOME/.zfunc" ]]; then
    mkdir -p "$HOME/.zfunc"
    rustup completions zsh > "$HOME/.zfunc/_rustup" 2>/dev/null
  fi
fi

# Cargo completions setup
if command -v cargo &>/dev/null; then
  if [[ ! -f "$HOME/.zfunc/_cargo" && -d "$HOME/.zfunc" ]]; then
    rustup completions zsh cargo > "$HOME/.zfunc/_cargo" 2>/dev/null
  fi
fi

# Aliases for common Rust commands
alias rs="rustc"
alias ru="rustup"
alias cb="cargo build"
alias cr="cargo run"
alias ct="cargo test"
alias cc="cargo check"
alias cw="cargo watch"
alias cf="cargo fmt"
alias cl="cargo clippy"
alias cnb="cargo +nightly build"
alias cnr="cargo +nightly run"

# Helper functions

# Run cargo bench with improved output
cargo-bench() {
  cargo bench --no-default-features "$@" -- -Z unstable-options --format json | jq .
}

# Create a new Rust project with sensible defaults
rust-new-project() {
  local project_name="$1"
  if [[ -z "$project_name" ]]; then
    echo "Usage: rust-new-project <project-name>"
    return 1
  fi

  cargo new --bin "$project_name"
  cd "$project_name" || return 1

  # Add common dependencies
  cargo add anyhow --features=std
  cargo add clap --features=derive
  cargo add serde --features=derive

  # Add dev dependencies
  cargo add --dev pretty_assertions

  # Initialize git repository if not already done by cargo
  if [[ ! -d ".git" ]]; then
    git init
    git add .
    git commit -m "Initial commit"
  fi

  echo "Created new Rust project: $project_name"
}

# Get the Rust version
rust-version() {
  rustc --version | awk '{print $2}'
}

# Cross compile for common targets
rust-cross-compile() {
  local target="$1"
  shift

  if [[ -z "$target" ]]; then
    echo "Available targets:"
    echo "  linux     - x86_64-unknown-linux-gnu"
    echo "  windows   - x86_64-pc-windows-gnu"
    echo "  mac       - x86_64-apple-darwin"
    echo "  mac-arm   - aarch64-apple-darwin"
    echo "  raspberry - armv7-unknown-linux-gnueabihf"
    return 0
  fi

  case "$target" in
    "linux")
      target="x86_64-unknown-linux-gnu"
      ;;
    "windows")
      target="x86_64-pc-windows-gnu"
      ;;
    "mac")
      target="x86_64-apple-darwin"
      ;;
    "mac-arm")
      target="aarch64-apple-darwin"
      ;;
    "raspberry")
      target="armv7-unknown-linux-gnueabihf"
      ;;
  esac

  if ! rustup target list --installed | grep -q "$target"; then
    echo "Target $target not installed. Installing..."
    rustup target add "$target"
  fi

  cargo build --release --target "$target" "$@"
}

# Clean up Rust project artifacts to free disk space
rust-clean-all() {

  # Clean cargo cache
  if command -v cargo-cache &>/dev/null; then
    local before_size=$(du -sh "$HOME/.cargo/registry" 2>/dev/null | awk '{print $1}')
    cargo cache -a
    local after_size=$(du -sh "$HOME/.cargo/registry" 2>/dev/null | awk '{print $1}')
    echo "Cleaned cargo cache: $before_size → $after_size"
  else
    echo "Install cargo-cache for better cache management: cargo install cargo-cache"
    cargo clean
  fi

  # Clean target directory in current project
  if [[ -d "./target" ]]; then
    local target_size=$(du -sh ./target 2>/dev/null | awk '{print $1}')
    rm -rf ./target
    echo "Cleaned target directory: $target_size"
  fi

  echo "Done cleaning Rust artifacts!"
}

# Show Rust project dependency tree
rust-deps() {
  if ! command -v cargo-tree &>/dev/null; then
    echo "Installing cargo-tree..."
    cargo install cargo-tree
  fi
  cargo tree "$@"
}

# Analyze Rust binary size
rust-analyze-size() {
  if ! command -v cargo-bloat &>/dev/null; then
    echo "Installing cargo-bloat..."
    cargo install cargo-bloat
  fi
  cargo bloat --release "$@"
}

# Initialize rust plugin hooks
script_dir="${0:a:h}"
rad_plugin_init_hooks+=("rad_rust_plugin_init_hook:${script_dir}")

rad_rust_plugin_init_hook() {
  # Initialize any additional Rust-related configurations
  # Access script_dir with $1 if needed
}
