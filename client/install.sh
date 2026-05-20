#!/bin/bash
# install.sh — set up a PERSONAL PC (laptop / desktop) as a client.
# Run this ON your laptop, from inside the client/ folder. Idempotent.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../config.sh"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

# --- 0. Validate config ---------------------------------------------------
if [ "$SERVER_HOST" = "your-server" ] || [ "$SERVER_USER" = "youruser" ]; then
  echo "Edit config.sh first — set SERVER_HOST and SERVER_USER." >&2
  exit 1
fi

# --- 1. Tailscale ---------------------------------------------------------
say "1/4  Tailscale"
if ! command -v tailscale >/dev/null 2>&1 && [ ! -d "/Applications/Tailscale.app" ]; then
  echo "Tailscale not found. Install it, sign in with the SAME account as the"
  echo "server, then re-run this script:"
  echo "  brew install --cask tailscale"
  exit 1
fi
echo "ok — make sure the Tailscale app shows Connected."

# --- 2. SSH config --------------------------------------------------------
say "2/4  SSH config for '$SERVER_HOST'"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
if grep -q "^Host $SERVER_HOST\$" "$HOME/.ssh/config" 2>/dev/null; then
  echo "already present — skipping"
else
  cat >> "$HOME/.ssh/config" <<EOF

Host $SERVER_HOST
  HostName $SERVER_HOST
  User $SERVER_USER
  ServerAliveInterval 30
  ServerAliveCountMax 6
  TCPKeepAlive yes
EOF
  chmod 600 "$HOME/.ssh/config"
  echo "added (no RequestTTY — that would corrupt file downloads over SSH)"
fi

# --- 3. cmini launcher ----------------------------------------------------
say "3/4  Install cmini -> /usr/local/bin/cmini"
sudo install -m 0755 "$HERE/cmini" /usr/local/bin/cmini
if grep -q '^export CLAUDE_MINI_HOST=' "$HOME/.zshrc" 2>/dev/null; then
  echo "CLAUDE_MINI_HOST already in ~/.zshrc — leaving it"
else
  echo "export CLAUDE_MINI_HOST=$SERVER_HOST" >> "$HOME/.zshrc"
  echo "added 'export CLAUDE_MINI_HOST=$SERVER_HOST' to ~/.zshrc"
fi
export CLAUDE_MINI_HOST="$SERVER_HOST"

# --- 4. Test the connection ----------------------------------------------
say "4/4  Test connection to the server"
if ssh -o ConnectTimeout=10 "$SERVER_HOST" 'echo "  connected as $(whoami) on $(hostname)"'; then
  say "Client setup complete. Open a new terminal, then run:  cmini"
else
  echo
  echo "Could not connect. Check:"
  echo "  - Tailscale is running and Connected on this machine"
  echo "  - the server appears in:  tailscale status"
  echo "  - the server still has Tailscale SSH enabled"
  exit 1
fi
