#!/bin/bash
set -e

echo "=== Personal devcontainer setup starting ==="

# -----------------------------------------------------------------------------
# Persistent personal storage
# -----------------------------------------------------------------------------
# This directory is expected to be bind-mounted from the Docker host by the
# team's devcontainer.json.
PERSIST_ROOT="$HOME/.bash_backup/pi-dev"

PERSIST_NVM="$PERSIST_ROOT/nvm"
PERSIST_NPM_GLOBAL="$PERSIST_ROOT/npm-global"
PERSIST_PI="$PERSIST_ROOT/pi"

mkdir -p "$PERSIST_ROOT"
mkdir -p "$PERSIST_NVM"
mkdir -p "$PERSIST_NPM_GLOBAL"
mkdir -p "$PERSIST_PI"

echo "Using persistent personal storage at: $PERSIST_ROOT"

# -----------------------------------------------------------------------------
# Helper: move existing container-local directory into persistent storage,
# then replace it with a symlink.
# -----------------------------------------------------------------------------
link_persistent_dir() {
  local target="$1"
  local link="$2"

  # If the path is already a symlink, make sure it points where we want.
  if [ -L "$link" ]; then
    local current_target
    current_target="$(readlink "$link")"

    if [ "$current_target" != "$target" ]; then
      echo "Updating symlink: $link -> $target"
      rm "$link"
      ln -s "$target" "$link"
    fi

    return
  fi

  # If a real directory already exists in the container, migrate its contents.
  if [ -d "$link" ]; then
    echo "Migrating existing $link contents into $target"

    # Copy contents, including dotfiles, without failing if empty.
    cp -a "$link"/. "$target"/ 2>/dev/null || true

    local backup="$link.container-backup.$(date +%Y%m%d%H%M%S)"
    mv "$link" "$backup"
    echo "Moved old container-local directory to: $backup"
  elif [ -e "$link" ]; then
    echo "Warning: $link exists but is not a directory or symlink. Moving it aside."
    local backup="$link.container-backup.$(date +%Y%m%d%H%M%S)"
    mv "$link" "$backup"
  fi

  ln -s "$target" "$link"
  echo "Linked $link -> $target"
}

# Persist the main mutable directories.
link_persistent_dir "$PERSIST_NVM" "$HOME/.nvm"
link_persistent_dir "$PERSIST_NPM_GLOBAL" "$HOME/.npm-global"
link_persistent_dir "$PERSIST_PI" "$HOME/.pi"

# -----------------------------------------------------------------------------
# nvm + Node.js
# -----------------------------------------------------------------------------
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
export NVM_DIR="$HOME/.nvm"

if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "Installing nvm into persistent storage..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# Load nvm for this script session.
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

echo "Installing/using Node.js v22..."
nvm install 22
nvm alias default 22
nvm use 22

echo "Node version: $(node --version)"
echo "npm version: $(npm --version)"

# -----------------------------------------------------------------------------
# npm global prefix
# -----------------------------------------------------------------------------
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

mkdir -p "$NPM_CONFIG_PREFIX/bin"

# -----------------------------------------------------------------------------
# pi coding agent
# -----------------------------------------------------------------------------
if ! command -v pi >/dev/null 2>&1; then
  echo "Installing pi coding agent into persistent npm-global..."
  npm install -g @mariozechner/pi-coding-agent
else
  echo "pi coding agent already installed at: $(command -v pi)"
fi

echo "Pi version: $(pi --version 2>/dev/null || echo 'installed')"

# -----------------------------------------------------------------------------
# Shell config
# -----------------------------------------------------------------------------
# Ensure nvm, npm-global, and pi are available in every new bash terminal.
BASHRC="$HOME/.bashrc"

# Remove old block and rewrite it.
sed -i '/# == personal devcontainer setup ==/,/# == end personal devcontainer setup ==/d' "$BASHRC" 2>/dev/null || true

cat >> "$BASHRC" << 'EOF'

# == personal devcontainer setup ==
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Persistent nvm install
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Persistent npm globals
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
# == end personal devcontainer setup ==
EOF

# -----------------------------------------------------------------------------
# Optional one-time seed of pi config from dotfiles repo
# -----------------------------------------------------------------------------
# This is now only a seed/restore step. Your live config lives in:
#   ~/.bash_backup/pi-dev/pi
#
# Existing files are not overwritten.
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PI_CONFIG_SRC="$SCRIPT_DIR/pi-config"
# PI_CONFIG_DST="$HOME/.pi/agent"

# if [ -d "$PI_CONFIG_SRC" ]; then
#   echo "Seeding pi configuration from dotfiles repo, without overwriting existing files..."
#   mkdir -p "$PI_CONFIG_DST"
#   cp -rn "$PI_CONFIG_SRC"/. "$PI_CONFIG_DST"/ 2>/dev/null || true
# fi

echo "Persistent locations:"
echo "  nvm:        $PERSIST_NVM"
echo "  npm-global: $PERSIST_NPM_GLOBAL"
echo "  pi:         $PERSIST_PI"

echo "=== Personal devcontainer setup complete ==="
