#!/bin/bash
set -e

echo "=== Personal devcontainer setup starting ==="

# --- nvm + Node.js ---
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
export NVM_DIR="$HOME/.nvm"

if [ ! -d "$NVM_DIR" ]; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# Load nvm
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

echo "Installing Node.js v22..."
nvm install 22

echo "Node version: $(node --version)"

# --- npm global prefix (keeps global installs in a known location) ---
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"

# --- pi coding agent ---
if ! command -v pi &> /dev/null; then
  echo "Installing pi coding agent..."
  npm install -g @mariozechner/pi-coding-agent
fi

echo "Pi version: $(pi --version 2>/dev/null || echo 'installed')"

# --- Shell config ---
# Ensure nvm, npm-global, and any other PATH entries are available in
# every new terminal, not just the install session.
BASHRC="$HOME/.bashrc"

# Remove old block and rewrite it
sed -i '/# == personal devcontainer setup ==/,/# == end personal devcontainer setup ==/d' "$BASHRC" 2>/dev/null || true

cat >> "$BASHRC" << 'EOF'

# == personal devcontainer setup ==
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
# == end personal devcontainer setup ==
EOF

# --- Pi config files ---
# Copy pi config from dotfiles repo into ~/.pi/agent/ if present.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_CONFIG_SRC="$SCRIPT_DIR/pi-config"
PI_CONFIG_DST="$HOME/.pi/agent"

if [ -d "$PI_CONFIG_SRC" ]; then
  echo "Restoring pi configuration..."
  mkdir -p "$PI_CONFIG_DST"
  cp -rn "$PI_CONFIG_SRC"/. "$PI_CONFIG_DST"/ 2>/dev/null || true
fi

echo "=== Personal devcontainer setup complete ==="
