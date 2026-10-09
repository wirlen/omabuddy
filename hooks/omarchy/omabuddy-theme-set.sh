#!/usr/bin/env bash
# Omarchy theme-set hook for Omabuddy. Install: omarchy hook install theme-set <this file>
# Its arguments are ignored; the shared script sends only the event name.
set -u
f=~/.config/omarchy/plugins/wirlen.omabuddy/hooks/omarchy/omabuddy.sh
[[ -f "$f" ]] && bash "$f" themeChanged
exit 0
