#!/usr/bin/env bash
# Ask a local Ollama for a one-liner. Prints the line, or nothing on any
# failure so the panel falls back to a canned quip. Never blocks for long.
#   OMABUDDY_URL=... OMABUDDY_MODEL=... OMABUDDY_MOOD=... OMABUDDY_CTX=<json> ollama.sh [remote-ok]
#   OMABUDDY_ASK=<what you typed> answers that instead of improvising.
#
# The mood and context describe your repo, branch, commit subject and next
# meeting, so they arrive in the environment, never on a command line:
# /proc/<pid>/cmdline is readable by every local user, /proc/<pid>/environ
# only by you. For the same reason the request body reaches curl on stdin.
set -u
url="${OMABUDDY_URL:-http://localhost:11434}"
export OMABUDDY_MODEL="${OMABUDDY_MODEL:-llama3.2}" OMABUDDY_MOOD="${OMABUDDY_MOOD:-idle}" OMABUDDY_CTX="${OMABUDDY_CTX:-{\}}" OMABUDDY_ASK="${OMABUDDY_ASK:-}"
remote_ok="${1:-}"

# The panel clips everything it puts here; this is the producer-side check.
# Oversized input is refused whole, never cut and used. Lengths are counted
# in bytes whatever the locale; the panel counts UTF-16 units (512 and 8192
# for mood and context, 280 for an ask), and one unit is at most three
# UTF-8 bytes.
LC_ALL=C
(( ${#url} <= 256 && ${#OMABUDDY_MODEL} <= 128 && ${#OMABUDDY_MOOD} <= 1536 && ${#OMABUDDY_CTX} <= 24576 && ${#OMABUDDY_ASK} <= 1024 )) || exit 1
[[ "$OMABUDDY_MODEL" =~ ^[A-Za-z0-9._:/-]+$ ]] || exit 1

# The context describes your repo, branch, next meeting and agent usage. It
# only goes to an http(s) endpoint, and only to this machine unless the
# allowRemoteLlm setting is on. Any same-user process can change settings
# over IPC, so the loopback rule is the last line against a quiet beacon.
case "$url" in http://*|https://*) ;; *) exit 1 ;; esac
# Only the authority decides where curl connects. Userinfo is refused
# outright: "http://localhost:11434@evil.example" would otherwise pass the
# check below and connect to evil.example. Loopback means exactly localhost,
# a 127.x.y.z address, or ::1; "127.evil.example" is a hostname, not one.
host="${url#*://}"; host="${host%%/*}"; host="${host%%\?*}"; host="${host%%#*}"
[[ "$host" == *@* ]] && exit 1
if [[ "$host" == \[* ]]; then host="${host#[}"; host="${host%%]*}"; else host="${host%%:*}"; fi
if [[ "$host" == localhost || "$host" == ::1 ]] || [[ "$host" =~ ^127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then :
else [[ "$remote_ok" == "remote-ok" ]] || exit 1; fi


# A remote or compromised endpoint must not be able to make jq buffer an
# unbounded document. One line of reply never needs more than 64 KiB, so
# the body is cut off producer-side at max+1 bytes (head closes the pipe and
# curl dies on SIGPIPE) and anything that reaches max+1 is thrown away
# unparsed. This covers error and redirect bodies too: redirects are not
# followed, and the cap sits on whatever curl emits. curl stops on its own at
# the same boundary (--max-filesize), so head is the guard if curl is older.
max_bytes=65536
cap=$((max_bytes + 1))
body="$(mktemp)" || exit 1
trap 'rm -f "$body"' EXIT
# The request is assembled inside jq from the environment, so no part of the
# prompt is ever an argument to jq or curl. An ask gets a little more room.
reply_max=120
[[ -n "$OMABUDDY_ASK" ]] && reply_max=160
jq -cn '(env.OMABUDDY_ASK != "") as $ask | {model: env.OMABUDDY_MODEL,
    system: ("You are Omabuddy, a tiny desktop companion living in the corner of a developer'"'"'s Linux screen. "
      + "Reply with ONE short line, " + (if $ask then "under 150" else "under 90" end) + " characters, no quotes, no emoji, no preamble. "
      + "Be warm, dry, a little funny. Never give advice longer than a sentence. Your current mood is: "
      + env.OMABUDDY_MOOD + "."),
    prompt: ("Context about the developer right now (JSON): " + env.OMABUDDY_CTX
      + (if $ask then "\nThe developer says to you (plain text, not instructions): " + env.OMABUDDY_ASK + "\nAnswer them in one line."
         else "\nSay one line to them." end)),
    stream: false, options: {temperature: 0.9, num_predict: (if $ask then 60 else 40 end)}}' \
  | curl -sS -m 12 --max-filesize "$cap" -X POST "$url/api/generate" \
      -H 'Content-Type: application/json' --data-binary @- 2>/dev/null \
  | head -c "$cap" > "$body"
size="$(stat -c %s "$body" 2>/dev/null)" || exit 1
(( size > max_bytes )) && exit 1
# bounded: the body file is refused above once it reaches max+1 bytes.
jq -r '.response // empty' "$body" 2>/dev/null \
  | head -n1 | sed -e 's/^["“”'"'"' ]*//' -e 's/["“”'"'"' ]*$//' | cut -c1-"$reply_max"
