# Shared by probe.sh and config.sh, so the bounded readers exist once.
# Sourced, never run:  . "${BASH_SOURCE[0]%/*}/lib.sh" || exit 1
set -u   # callers set it too; repeated so the file stands on its own

# Stderr goes back to the panel, which keeps it in memory: cap it too.
exec 2> >(head -c 4096 >&2)

# Bounded, no-follow read of a file we did not write: refuses symlinks and
# anything that is not a regular file, then emits at most max+1 bytes so a
# file that grows under us still cannot exceed the cap. Callers treat a
# document cut at max+1 as unparseable, which jq guarantees for objects.
read_capped() {
  local f="$1" max="$2" size
  [[ -f "$f" && ! -L "$f" && -r "$f" ]] || return 1
  size="$(stat -c %s -- "$f" 2>/dev/null)" || return 1
  (( size <= max )) || return 1
  head -c "$((max + 1))" -- "$f"
}
# Same cap on a tool's stdout: nothing past max+1 bytes is ever buffered.
run_capped() { local max="$1"; shift; "$@" 2>/dev/null | head -c "$((max + 1))"; }

# Config files (shell.json, a theme's colors.toml) are often dotfile-manager
# symlinks. Only for those: resolve the link to its final target, which
# read_capped then checks like any other file. Paths a repo controls never
# come through here.
resolve_link() {
  if [[ -L "$1" ]]; then readlink -e -- "$1" 2>/dev/null | head -c 4097
  else printf '%s' "$1"; fi
}
