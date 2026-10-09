#!/usr/bin/env bash
# Run a command and let Omabuddy judge it: passed on exit 0, failed
# otherwise. Exits with the command's own status, so it drops into scripts.
#   ~/.config/omarchy/plugins/wirlen.omabuddy/hooks/judge.sh npm test
# Only the verdict is sent; the command's output stays in your terminal.
set -u
(( $# > 0 )) || { echo "usage: judge.sh <command> [args...]" >&2; exit 2; }
"$@"
status=$?
if command -v omarchy-shell >/dev/null 2>&1; then
  if (( status == 0 )); then verdict=passed; else verdict=failed; fi
  # In the background, so a busy shell never delays the exit status.
  ( omarchy-shell -q omabuddy event "$verdict" >/dev/null 2>&1 & )
fi
exit "$status"
