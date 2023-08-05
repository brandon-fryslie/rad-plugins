# Golang plugin for use with Homebrew Go installation

rad-init-golang() {
  if [[ -z $GOPATH ]]; then
    export GOPATH=$HOME/golang
    export PATH="$PATH:$GOPATH/bin"
  fi
}

rad-init-golang
