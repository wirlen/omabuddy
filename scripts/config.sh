#!/usr/bin/env bash
# Reads one of the two files the panel follows, bounded in bytes, and prints
# one JSON object. The panel only watches those files for changes; this
# script is what reads them, so the long-lived shell process never loads
# either one whole.
#   config.sh <plugin-id> entry    {"entry": <this plugin's entry in shell.json, or null>}
#   config.sh <plugin-id> colors   {"colors": {<name>: "#rrggbb", ...} from the theme's colors.toml}
set -u

. "${BASH_SOURCE[0]%/*}/lib.sh" || exit 1   # stderr cap, read_capped, resolve_link

config_max=1048576   # bytes of shell.json parsed
colors_max=65536     # bytes of colors.toml scanned
colors_count=64      # colour lines kept
entry_max=32768      # bytes of our entry passed on
id="${1:-wirlen.omabuddy}"
part="${2:-entry}"
[[ "$id" =~ ^[A-Za-z0-9._-]{1,128}$ ]] || exit 1

case "$part" in
  entry)
    entry="$(read_capped "$(resolve_link "$HOME/.config/omarchy/shell.json")" "$config_max" \
      | OB_ID="$id" jq -c 'first(.plugins[]? | objects | select(.id == env.OB_ID)) // {}' 2>/dev/null \
      | head -c "$((entry_max + 1))")"
    (( ${#entry} <= entry_max )) && [[ "$entry" == \{* ]] || entry="null"
    # jq's compact output; printf is a builtin, so it never lands on a command line.
    printf '{"entry":%s}\n' "$entry"
    ;;
  colors)
    # Only `name = "#hex"` lines leave the theme file.
    colors="$(read_capped "$(resolve_link "$HOME/.local/state/omarchy/current/theme/colors.toml")" "$colors_max" \
      | grep -E '^[[:space:]]*[a-z_]{1,32}[[:space:]]*=[[:space:]]*"#[0-9a-fA-F]{6,8}"' | head -n "$colors_count" \
      | jq -Rcn '[inputs | capture("^\\s*(?<k>[a-z_]+)\\s*=\\s*\"(?<v>#[0-9a-fA-F]{6,8})\"")] | map({(.k): .v}) | add // {}' 2>/dev/null \
      | head -c 4097)"
    [[ "$colors" == \{* && ${#colors} -le 4096 ]] || colors="{}"
    printf '{"colors":%s}\n' "$colors"
    ;;
  *) exit 1 ;;
esac
