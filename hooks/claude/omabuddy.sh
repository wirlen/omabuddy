#!/usr/bin/env bash
# Claude Code hook: tell Omabuddy an agent finished (Stop) or wants you
# (Notification). Takes the kind as its only argument and reads nothing from
# stdin, so the hook payload (prompts, paths, messages) never reaches it.
#
#   "Stop":         [{ "hooks": [{ "type": "command", "command": "<this> stop" }] }]
#   "Notification": [{ "hooks": [{ "type": "command", "command": "<this> notification" }] }]
set -u
case "${1:-}" in
  stop) event=agentDone ;;
  notification) event=agentWaiting ;;
  *) exit 0 ;;
esac
command -v omarchy-shell >/dev/null 2>&1 || exit 0
omarchy-shell -q omabuddy event "$event" >/dev/null 2>&1 &
exit 0
