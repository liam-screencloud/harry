#!/bin/bash
# office-hours setup — one-time setup for the /office-hours loop.
# Idempotent: safe to run repeatedly. No global files touched.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
info() { printf "  %s\n" "$1"; }

echo "Setting up /office-hours …"

# 1. Make schedule.sh executable
if [ -f "$SCRIPT_DIR/schedule.sh" ]; then
  chmod +x "$SCRIPT_DIR/schedule.sh"
  ok "schedule.sh is executable"
else
  warn "schedule.sh missing at $SCRIPT_DIR/schedule.sh — create it before starting the loop"
fi

# 2. Tool checks (warn, don't fail)
if command -v gh >/dev/null 2>&1; then
  ok "gh is installed"
else
  warn "gh is not on PATH — install with: brew install gh"
fi

if command -v jq >/dev/null 2>&1; then
  ok "jq is installed"
else
  warn "jq is not on PATH — install with: brew install jq"
fi

# 3. Auth check
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    ok "gh is authenticated"
  else
    warn "gh is not authenticated — run: gh auth login"
  fi
fi

# 4. Next steps
echo ""
echo "Setup complete."
echo ""
echo "Start the loop:  ./.claude/skills/office-hours/schedule.sh -i 30m -b"
echo "Stop:            kill \$(cat ~/.claude/office-hours.pid)"
echo "Tail logs:       tail -f ~/.claude/office-hours.log"
