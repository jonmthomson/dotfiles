#!/bin/bash
set -e

echo "=== Personal devcontainer setup starting ==="

# --- nvm + Node.js ---
export NVM_DIR="$HOME/.nvm"

if [ ! -d "$NVM_DIR" ]; then
  echo "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi

# Load nvm
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! command -v node &> /dev/null; then
  echo "Installing Node.js LTS..."
  nvm install --lts
fi

echo "Node version: $(node --version)"

# --- npm global prefix (keeps global installs in a known location) ---
npm config set prefix "$HOME/.npm-global"
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

if ! grep -q '# == personal devcontainer setup ==' "$BASHRC" 2>/dev/null; then
  cat >> "$BASHRC" << 'EOF'

# == personal devcontainer setup ==
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
export PATH="$HOME/.npm-global/bin:$PATH"
# == end personal devcontainer setup ==
EOF
fi

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
