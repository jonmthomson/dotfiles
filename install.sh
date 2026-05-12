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
PERSIST_PI="$PERSIST_ROOT/pi"

mkdir -p "$PERSIST_ROOT"
mkdir -p "$PERSIST_NVM"
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
#
# Note:
# We intentionally do NOT persist ~/.npm-global.
# With nvm, global npm packages live under ~/.nvm/versions/node/<version>/,
# so persisting ~/.nvm also persists global npm packages.
link_persistent_dir "$PERSIST_NVM" "$HOME/.nvm"
link_persistent_dir "$PERSIST_PI" "$HOME/.pi"

# -----------------------------------------------------------------------------
# nvm + Node.js
# -----------------------------------------------------------------------------
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
export NVM_DIR="$HOME/.nvm"

# nvm is not compatible with NPM_CONFIG_PREFIX.
# Make sure it is not set in this install session.
unset NPM_CONFIG_PREFIX

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
echo "npm global prefix: $(npm prefix -g)"

# -----------------------------------------------------------------------------
# PATH
# -----------------------------------------------------------------------------
# Do not add ~/.npm-global/bin here.
# nvm adds the active Node version's bin directory to PATH when nvm use/default
# is applied. Keep ~/.local/bin for personal user tools.
export PATH="$HOME/.local/bin:$PATH"

# Clear bash's command lookup cache in case pi previously resolved from
# ~/.npm-global/bin in this shell.
hash -r 2>/dev/null || true

# -----------------------------------------------------------------------------
# pi coding agent
# -----------------------------------------------------------------------------
if ! command -v pi >/dev/null 2>&1; then
  echo "Installing pi coding agent into nvm-managed global npm location..."
  npm install -g @earendil-works/pi-coding-agent
else
  echo "pi coding agent already installed at: $(command -v pi)"
fi

hash -r 2>/dev/null || true

# ---------------------------------------------------------------------
# Make pi globally accessible (no shell init required)
# ---------------------------------------------------------------------
PI_PATH="$(command -v pi || true)"

if [ -n "$PI_PATH" ]; then
  echo "Linking pi into /usr/local/bin..."
  sudo ln -sf "$PI_PATH" /usr/local/bin/pi

  echo "Global pi path: $(command -v pi)"
else
  echo "Warning: pi not found after installation"
fi

echo "Pi path: $(command -v pi || echo 'not found')"
echo "Pi version: $(pi --version 2>/dev/null || echo 'installed')"


# -----------------------------------------------------------------------------
# just (via npm rust-just)
# -----------------------------------------------------------------------------
if ! command -v just >/dev/null 2>&1; then
  echo "Installing just (rust-just) into nvm-managed global npm location..."
  npm install -g rust-just
else
  echo "just already installed at: $(command -v just)"
fi

hash -r 2>/dev/null || true

echo "just path: $(command -v just || echo 'not found')"
echo "just version: $(just --version 2>/dev/null || echo 'installed')"


# -----------------------------------------------------------------------------
# Shell config
# -----------------------------------------------------------------------------
# Ensure nvm and pi are available in every new bash terminal.
BASHRC="$HOME/.bashrc"

# Remove old block and rewrite it.
sed -i '/# == personal devcontainer setup ==/,/# == end personal devcontainer setup ==/d' "$BASHRC" 2>/dev/null || true

cat >> "$BASHRC" << 'EOF'

# == personal devcontainer setup ==
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

# Persistent nvm install.
# Global npm packages are intentionally managed by nvm and therefore live under:
#   ~/.nvm/versions/node/<version>/
export NVM_DIR="$HOME/.nvm"

# nvm is not compatible with NPM_CONFIG_PREFIX.
unset NPM_CONFIG_PREFIX

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# Personal user binaries.
# Do not add ~/.npm-global/bin here.
export PATH="$HOME/.local/bin:$PATH"
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
echo "  nvm: $PERSIST_NVM"
echo "  pi:  $PERSIST_PI"

echo "=== Personal devcontainer setup complete ==="
