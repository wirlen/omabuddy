#!/usr/bin/env bash
# Ask a local Ollama for a one-liner. Prints the line, or nothing on any
# failure so the panel falls back to a canned quip. Never blocks for long.
#   ollama.sh <url> <model> <mood> <context-json> [remote-ok]
set -u
url="${1:-http://localhost:11434}"
model="${2:-llama3.2}"
mood="${3:-idle}"
ctx="${4:-{\}}"
remote_ok="${5:-}"

# The context describes your repo, branch, next meeting and agent usage. It
# only goes to an http(s) endpoint, and only to this machine unless the
# allowRemoteLlm setting is on. Any same-user process can change settings
# over IPC, so the loopback rule is the last line against a quiet beacon.
case "$url" in http://*|https://*) ;; *) exit 1 ;; esac
host="${url#*://}"; host="${host%%/*}"
if [[ "$host" == \[* ]]; then host="${host#[}"; host="${host%%]*}"; else host="${host%%:*}"; fi
case "$host" in
  localhost|127.*|::1) ;;
  *) [[ "$remote_ok" == "remote-ok" ]] || exit 1 ;;
esac

system="You are Omabuddy, a tiny desktop companion living in the corner of a developer's Linux screen. \
Reply with ONE short line, under 90 characters, no quotes, no emoji, no preamble. \
Be warm, dry, a little funny. Never give advice longer than a sentence. Your current mood is: $mood."

prompt="Context about the developer right now (JSON): $ctx
Say one line to them."

payload="$(jq -cn --arg m "$model" --arg s "$system" --arg p "$prompt" \
  '{model:$m, system:$s, prompt:$p, stream:false, options:{temperature:0.9, num_predict:40}}')"

# A remote or compromised endpoint must not be able to make jq buffer an
# unbounded document. One line of reply never needs more than 64 KiB, so
# the body is cut off producer-side at max+1 bytes (head closes the pipe and
# curl dies on SIGPIPE) and anything that reaches max+1 is thrown away
# unparsed. This covers error and redirect bodies too: redirects are not
# followed, and the cap sits on whatever curl emits. curl stops on its own at
# the same boundary (--max-filesize), so head is the guard if curl is older.
max_bytes=65536
body="$(mktemp)" || exit 1
trap 'rm -f "$body"' EXIT
curl -sS -m 12 --max-filesize "$((max_bytes + 1))" -X POST "$url/api/generate" \
  -H 'Content-Type: application/json' -d "$payload" 2>/dev/null \
  | head -c "$((max_bytes + 1))" > "$body"
size="$(stat -c %s "$body" 2>/dev/null)" || exit 1
(( size > max_bytes )) && exit 1
jq -r '.response // empty' "$body" 2>/dev/null \
  | head -n1 | sed -e 's/^["“”'"'"' ]*//' -e 's/["“”'"'"' ]*$//' | cut -c1-120
