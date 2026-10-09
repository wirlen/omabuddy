#!/usr/bin/env bash
# Omarchy battery-low hook for Omabuddy. Install: omarchy hook install battery-low <this file>
# Its arguments are ignored; the shared script sends only the event name.
set -u
f=~/.config/omarchy/plugins/wirlen.omabuddy/hooks/omarchy/omabuddy.sh
[[ -f "$f" ]] && bash "$f" batteryLow
exit 0
