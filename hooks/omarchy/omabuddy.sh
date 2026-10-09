#!/usr/bin/env bash
# Shared body of the Omarchy hooks (omabuddy-<hook>.sh next to this file):
# tells Omabuddy the theme or font changed, an update finished, or the
# battery is low. The installed hooks are one-line wrappers that call this
# file inside the plugin, so a plugin update reaches them without
# reinstalling.
#   omabuddy.sh <themeChanged|fontChanged|updated|batteryLow>
# Only the event name is sent, in the background, so the caller never
# waits. A font change restarts the shell right before its hook runs, so
# this waits (up to 15 s) for the buddy to be listening again.
set -u
case "${1:-}" in
  themeChanged|fontChanged|updated|batteryLow) event="$1" ;;
  *) exit 0 ;;
esac
command -v omarchy-shell >/dev/null 2>&1 || exit 0
(
  for _ in $(seq 1 15); do
    omarchy-shell omabuddy state >/dev/null 2>&1 && break
    sleep 1
  done
  omarchy-shell -q omabuddy event "$event" >/dev/null 2>&1
) >/dev/null 2>&1 &
exit 0
