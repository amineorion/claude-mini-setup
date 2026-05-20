# config.sh — central settings. Every script in this repo reads these values.
#
#   >>> EDIT THIS FILE FIRST, then run the install scripts. <<<
#
# POSIX sh syntax — keep each line `KEY="value"`.

# --- Server: the always-on Mac ---
SERVER_HOST="your-server"      # the server's Tailscale machine name
SERVER_USER="youruser"         # your macOS username on the server

# --- Notifications (ntfy.sh) ---
# Generate a private topic ON THE SERVER:   echo "claude-$(openssl rand -hex 12)"
# Anyone who knows this topic can read and post your notifications — treat it
# as a secret. A repo containing a real one must NOT be public.
NTFY_TOPIC="REPLACE-WITH-YOUR-NTFY-TOPIC"

# --- Projects: one always-on Claude session per folder under ~/workspaces ---
PROJECTS="project-a project-b project-c"

# --- Paths on the server ---
WORKSPACES="$HOME/workspaces"
