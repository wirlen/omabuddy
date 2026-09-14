#!/usr/bin/env bash
# Deterministic pre-push audit for the patterns the Omarchy marketplace
# security reviewer flags: inputs that are bounded in time but not in bytes,
# unparsed remote bodies, files read with symlinks followed, process trees
# that outlive a timeout, and collectors that buffer to end-of-stream.
#
#   .claude/skills/bounded-inputs/audit.sh [path...]   (default: repo root)
#
# Exit 1 on any finding. A line that is bounded in a way the rules cannot
# see may carry a trailing "# bounded: <why>" comment, which suppresses the
# finding and records the reason for the next reader.
set -u
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
[[ $# -gt 0 ]] || set -- "$root"
findings=0
flag() { printf '%s:%s: [%s] %s\n' "$1" "$2" "$3" "$4"; findings=$((findings + 1)); }

# Words that make a captured command's output bounded.
bounders='head -c|head -n|tail -n|wc -[lc]|\| *awk|--count|-1 |--max-count|clip |read_capped|run_capped|--show-toplevel|-r .pid|--arg|-cn '
# External tools whose output is untrusted and potentially unbounded.
tools='git |hyprctl |curl |cat |find |ls |jq |grep |journalctl |cal |omacal |pgrep '

while IFS= read -r -d '' f; do
  rel="${f#"$root"/}"
  mapfile -t lines < "$f"
  for (( i = 0; i < ${#lines[@]}; i++ )); do
    line="${lines[i]}"; n=$((i + 1))
    # Commands continued with a trailing backslash are judged as one unit.
    unit="$line"; j=$i
    while [[ "${lines[j]}" =~ \\$ ]] && (( j + 1 < ${#lines[@]} )); do j=$((j + 1)); unit+=" ${lines[j]}"; done
    [[ "$line" =~ \#\ bounded: ]] && continue
    (( i > 0 )) && [[ "${lines[i-1]}" =~ ^[[:space:]]*#\ bounded: ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    case "$f" in
      *.sh|*.bash)
        # 1. Command substitution over an external tool with nothing bounding it.
        if [[ "$line" =~ \$\( ]] && grep -qE "\\\$\\(($tools)|\\| *($tools)" <<<"$line" && ! grep -qE "$bounders" <<<"$line"; then
          flag "$rel" "$n" unbounded-capture "command substitution keeps a tool's whole output; pipe through head -c/-n or count it"
        fi
        # 2. Whole-file reads: $(<f), <"$f", cat f, or jq/grep given a file, outside read_capped.
        if grep -qE '\$\(<|< *"?\$|(^|[ |(])cat +"?[\$/~]' <<<"$line" && ! grep -qE 'head -c|read_capped|read -r' <<<"$line"; then
          flag "$rel" "$n" unbounded-file-read "file read in full; use read_capped (size check, no-follow, head -c max+1)"
        fi
        if grep -qE "jq .*' +\"\\\$[a-z_]+\"|jq .*\\*\\.json" <<<"$unit" && ! grep -qE 'read_capped|head -c' <<<"$unit"; then
          flag "$rel" "$n" jq-reads-file "jq buffers the whole document; feed it through read_capped/head -c instead of a path"
        fi
        # 3. curl: byte cap plus no redirects, and the body must go through head -c.
        if [[ "$line" =~ curl\  ]]; then
          grep -qE -- '--max-filesize' <<<"$unit" || flag "$rel" "$n" curl-no-max-filesize "curl without --max-filesize"
          grep -qE 'head -c' <<<"$unit" || flag "$rel" "$n" curl-no-head "curl body not cut off with head -c max+1 before parsing"
          grep -qE -- ' -L | --location' <<<"$unit" && flag "$rel" "$n" curl-follows-redirects "curl follows redirects; drop -L"
        fi
        # 4. Shell-level footguns.
        grep -qE '(^|[ ;])eval ' <<<"$line" && flag "$rel" "$n" eval "eval on data"
        grep -qE 'jq .*"\\\(\$' <<<"$line" && flag "$rel" "$n" jq-string-splice "variable spliced into a jq filter; use --arg"
        ;;
      *.qml)
        if [[ "$line" =~ \"timeout\" ]] && ! grep -qE '"-k"' <<<"$line"; then
          flag "$rel" "$n" timeout-no-kill "timeout without -k: a child ignoring SIGTERM survives"
        fi
        ;;
    esac
  done
  case "$f" in
    *.qml)
      c="$(grep -c 'StdioCollector' "$f")"
      if (( c > 0 )) && ! grep -qE '\.length *>|MaxBytes|slice\(0,' "$f"; then
        flag "$rel" 0 collector-unbounded "StdioCollector buffers to end-of-stream with no byte cap on the consumer side"
      fi
      grep -qE 'JSON\.parse' "$f" && ! grep -qE 'typeof .* !== "object"' "$f" \
        && flag "$rel" 0 json-shape-unchecked "JSON.parse result used without checking it is an object"
      ;;
    *.sh)
      # 5. Every script that talks to a process tree must state its time bound.
      grep -qE '^set -u' "$f" || flag "$rel" 0 no-set-u "script does not set -u"
      ;;
  esac
done < <(find "$@" \( -name '*.sh' -o -name '*.bash' -o -name '*.qml' \) -not -path '*/.git/*' -not -path '*/.claude/*' -print0)

# 6. Manifest version must move when scripts or QML changed since the last tag/commit on origin.
if git -C "$root" rev-parse --verify -q origin/main >/dev/null; then
  if ! git -C "$root" diff --quiet origin/main -- scripts '*.qml' '*.js' 2>/dev/null \
     && git -C "$root" diff --quiet origin/main -- manifest.json 2>/dev/null; then
    flag manifest.json 0 version-not-bumped "code changed since origin/main but manifest version did not"
  fi
  if ! git -C "$root" diff --quiet origin/main -- scripts/probe.sh scripts/ollama.sh 2>/dev/null \
     && git -C "$root" diff --quiet origin/main -- README.md 2>/dev/null; then
    flag README.md 0 privacy-section-stale "probe or ollama script changed but README privacy section did not"
  fi
fi

if (( findings > 0 )); then
  printf '\n%d finding(s). Fix them, or add "# bounded: <reason>" on a line the rules cannot see through.\n' "$findings"
  exit 1
fi
echo "bounded-inputs audit: clean"
