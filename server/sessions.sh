#!/bin/bash
# sessions.sh — manage the always-on Claude sessions on the SERVER.
#
#   ./sessions.sh start     start one detached Claude per project (skips running)
#   ./sessions.sh list      list running sessions
#   ./sessions.sh restart   kill + recreate every project session
#   ./sessions.sh stop      kill every project session
#
# Reads PROJECTS and WORKSPACES from ../config.sh.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../config.sh"

TMUX="$(command -v tmux || echo /opt/homebrew/bin/tmux)"
CLAUDE="$(command -v claude || echo "$HOME/.local/bin/claude")"

start_one() {
  p="$1"
  if "$TMUX" has-session -t "$p" 2>/dev/null; then
    echo "  = $p (already running)"; return
  fi
  if [ ! -d "$WORKSPACES/$p" ]; then
    echo "  ! $p (no folder $WORKSPACES/$p — skipped)"; return
  fi
  "$TMUX" new-session -d -s "$p" -c "$WORKSPACES/$p" \
    "$CLAUDE" --dangerously-skip-permissions
  echo "  + $p (started)"
}

case "${1:-start}" in
  start)
    echo "Starting project sessions:"
    for p in $PROJECTS; do start_one "$p"; done
    echo; "$TMUX" ls 2>/dev/null || true ;;
  list|ls)
    "$TMUX" ls 2>/dev/null || echo "(no sessions running)" ;;
  stop)
    echo "Stopping project sessions:"
    for p in $PROJECTS; do
      "$TMUX" kill-session -t "$p" 2>/dev/null && echo "  - $p (killed)" || true
    done ;;
  restart)
    echo "Restarting project sessions:"
    for p in $PROJECTS; do "$TMUX" kill-session -t "$p" 2>/dev/null || true; done
    for p in $PROJECTS; do start_one "$p"; done ;;
  *)
    echo "usage: ./sessions.sh [start|list|stop|restart]"; exit 1 ;;
esac
