#!/bin/bash
# install.sh — set up the SERVER (the always-on Mac mini).
# Run this ON the server. Idempotent: safe to re-run any time.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../config.sh"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

# --- 0. Validate config ---------------------------------------------------
if [ "$NTFY_TOPIC" = "REPLACE-WITH-YOUR-NTFY-TOPIC" ]; then
  echo "Edit config.sh first — set NTFY_TOPIC (generate one with:" >&2
  echo "  echo \"claude-\$(openssl rand -hex 12)\"  )." >&2
  exit 1
fi

# --- 1. Homebrew ----------------------------------------------------------
say "1/7  Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it first: https://brew.sh" >&2
  exit 1
fi
echo "ok — $(brew --version | head -1)"

# --- 2. Tailscale + tmux --------------------------------------------------
say "2/7  Install Tailscale + tmux"
brew install tailscale tmux
sudo brew services start tailscale

# --- 3. Tailscale SSH -----------------------------------------------------
say "3/7  Enable Tailscale SSH"
echo "If a https://login.tailscale.com/... URL appears, open it and approve this Mac."
sudo tailscale up --ssh
echo "Tailscale name: $(tailscale status --self --json 2>/dev/null | grep -m1 '\"DNSName\"' | cut -d'\"' -f4 || echo '?')"
echo "Tailscale IP:   $(tailscale ip -4)"

# --- 4. ct helper ---------------------------------------------------------
say "4/7  Install ct helper -> ~/.local/bin/ct"
mkdir -p "$HOME/.local/bin"
install -m 0755 "$HERE/ct" "$HOME/.local/bin/ct"
echo "ok"

# --- 5. Notification hooks ------------------------------------------------
say "5/7  Notification hooks -> ~/.claude/settings.json"
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found — needed to merge settings.json safely." >&2
  echo "Install Xcode command line tools:  xcode-select --install" >&2
  exit 1
fi
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)" && echo "backed up existing settings.json"
python3 - "$SETTINGS" "$NTFY_TOPIC" <<'PY'
import json, os, sys
path, topic = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        data = json.load(open(path))
    except Exception:
        data = {}
guard = 'case "$PWD" in "$HOME/workspaces/"*) '
def cmd(title, tags, body, prio=False):
    p = "-H 'Priority: high' " if prio else ""
    return (guard + 'curl -fsS -X POST -H "Title: %s" %s-H \'Tags: %s\' '
            '-d "%s" https://ntfy.sh/%s >/dev/null 2>&1 ;; esac; true'
            % (title, p, tags, body, topic))
hooks = data.setdefault("hooks", {})
hooks["Notification"] = [{"hooks": [{"type": "command",
    "command": cmd("$(basename $PWD) needs input", "bell",
                   "Claude is waiting in $(basename $PWD)", prio=True)}]}]
hooks["Stop"] = [{"hooks": [{"type": "command",
    "command": cmd("$(basename $PWD) finished", "white_check_mark",
                   "Claude finished in $(basename $PWD)")}]}]
json.dump(data, open(path, "w"), indent=2)
open(path, "a").write("\n")
print("ok — Notification + Stop hooks point at ntfy.sh/" + topic)
PY

# --- 6. Keep the Mac awake ------------------------------------------------
say "6/7  Keep the Mac awake on AC power"
sudo pmset -c sleep 0 disablesleep 1
echo "ok — also check System Settings > Energy: prevent sleep when display off."

# --- 7. Silence the SSH login banner -------------------------------------
say "7/7  Silence the SSH login banner"
touch "$HOME/.hushlogin"
echo "ok"

say "Server setup complete."
echo "Next:  ./sessions.sh start    (launch your $(echo $PROJECTS | wc -w | tr -d ' ') project sessions)"
