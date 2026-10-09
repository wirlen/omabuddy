#!/usr/bin/env bash
# Omarchy font-set hook for Omabuddy. Install: omarchy hook install font-set <this file>
# Its arguments are ignored; the shared script sends only the event name.
set -u
f=~/.config/omarchy/plugins/wirlen.omabuddy/hooks/omarchy/omabuddy.sh
[[ -f "$f" ]] && bash "$f" fontChanged
exit 0
