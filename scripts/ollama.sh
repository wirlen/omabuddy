#!/usr/bin/env bash
# Ask a local Ollama for a one-liner. Prints the line, or nothing on any
# failure so the panel falls back to a canned quip. Never blocks for long.
#   ollama.sh <url> <model> <mood> <context-json>
set -u
url="${1:-http://localhost:11434}"
model="${2:-llama3.2}"
# The context below describes your working directory, branch, next meeting
# and agent usage. It only ever goes to an http(s) endpoint you configured.
case "$url" in http://*|https://*) ;; *) exit 1 ;; esac
mood="${3:-idle}"
ctx="${4:-{\}}"

system="You are Omabuddy, a tiny desktop companion living in the corner of a developer's Linux screen. \
Reply with ONE short line, under 90 characters, no quotes, no emoji, no preamble. \
Be warm, dry, a little funny. Never give advice longer than a sentence. Your current mood is: $mood."

prompt="Context about the developer right now (JSON): $ctx
Say one line to them."

payload="$(jq -cn --arg m "$model" --arg s "$system" --arg p "$prompt" \
  '{model:$m, system:$s, prompt:$p, stream:false, options:{temperature:0.9, num_predict:40}}')"

curl -sS -m 12 -X POST "$url/api/generate" -H 'Content-Type: application/json' -d "$payload" 2>/dev/null \
  | jq -r '.response // empty' \
  | head -n1 | sed -e 's/^["“”'"'"' ]*//' -e 's/["“”'"'"' ]*$//' | cut -c1-120
