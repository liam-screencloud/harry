#!/bin/bash
# office-hours scheduler — runs /office-hours on a loop via claude /loop
#
# Usage:
#   ./schedule.sh                  start loop every 30 minutes (foreground)
#   ./schedule.sh -i 30m           loop every 30 minutes (foreground)
#   ./schedule.sh -i 2h            loop every 2 hours (foreground)
#   ./schedule.sh -b               run in background (default 30m)
#   ./schedule.sh -i 15m -b        run in background every 15 minutes
#   ./schedule.sh -h               show this help

INTERVAL="30m"
BACKGROUND=false

usage() {
  cat <<EOF
Usage: ./schedule.sh [OPTIONS]

Options:
  -i <interval>   Loop interval (e.g. 1m, 30m, 2h). Default: 30m
  -b              Run in background (detached from terminal)
  -h              Show this help

Examples:
  ./schedule.sh                  # foreground, every 30 minutes
  ./schedule.sh -i 30m           # foreground, every 30 minutes
  ./schedule.sh -i 2h -b         # background, every 2 hours
EOF
}

while getopts "i:bh" opt; do
  case $opt in
    i) INTERVAL="$OPTARG" ;;
    b) BACKGROUND=true ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

CMD="claude --dangerously-skip-permissions \"/loop ${INTERVAL} /office-hours\""

if $BACKGROUND; then
  LOG="$HOME/.claude/office-hours.log"
  echo "Starting office-hours in background (every ${INTERVAL})"
  echo "Logs: $LOG"
  echo "Stop: kill \$(cat $HOME/.claude/office-hours.pid)"
  eval "nohup $CMD >> \"$LOG\" 2>&1 & echo \$! > $HOME/.claude/office-hours.pid"
else
  echo "Starting office-hours (every ${INTERVAL}) — Ctrl+C to stop"
  echo ""
  eval "$CMD"
fi
