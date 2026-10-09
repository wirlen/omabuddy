#!/usr/bin/env bash
# Omarchy post-update hook for Omabuddy. Install: omarchy hook install post-update <this file>
# Its arguments are ignored; the shared script sends only the event name.
set -u
f=~/.config/omarchy/plugins/wirlen.omabuddy/hooks/omarchy/omabuddy.sh
[[ -f "$f" ]] && bash "$f" updated
exit 0
