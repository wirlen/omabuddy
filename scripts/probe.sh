#!/usr/bin/env bash
# Omabuddy sensor probe. Prints one JSON object describing the world the
# buddy lives in: the focused terminal's working directory and its git
# state, battery, CPU load, and the hour. Runs every few seconds from the
# panel, so it stays cheap and never blocks on anything.
set -u

pid="$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty')"
cwd=""
if [[ -n "${pid:-}" ]]; then
  # Walk to the deepest descendant: a terminal spawns a shell which spawns
  # whatever you're running, and that one has the cwd you actually care about.
  cur="$pid"
  for _ in $(seq 1 12); do
    child="$(pgrep -P "$cur" | tail -n1)"
    [[ -z "$child" ]] && break
    cur="$child"
  done
  cwd="$(readlink -e "/proc/$cur/cwd" 2>/dev/null || readlink -e "/proc/$pid/cwd" 2>/dev/null || true)"
fi

in_repo=false branch="" dirty=0 untracked=0 ahead=0 last_commit=0 repo=""
if [[ -n "$cwd" ]] && top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"; then
  in_repo=true
  repo="$(basename "$top")"
  branch="$(git -C "$top" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
  dirty="$(git -C "$top" diff --numstat HEAD 2>/dev/null | awk '{a+=$1; d+=$2} END {print a+d+0}')"
  untracked="$(git -C "$top" ls-files --others --exclude-standard 2>/dev/null | wc -l)"
  ahead="$(git -C "$top" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  last_commit="$(git -C "$top" log -1 --format=%ct 2>/dev/null || echo 0)"
fi

battery=-1 charging=false
for bat in /sys/class/power_supply/BAT*; do
  [[ -r "$bat/capacity" ]] || continue
  battery="$(<"$bat/capacity")"
  case "$(<"$bat/status")" in Charging|Full) charging=true ;; esac
  break
done

# Calendar: the OmaCal plugin's feed, if OmaCal is installed. Next event that
# has not ended yet, minutes until it starts (negative while ongoing).
cal_title="" cal_eta=0 cal_has=false
feed="${XDG_STATE_HOME:-$HOME/.local/state}/omacal/upcoming.json"
if [[ -r "$feed" ]]; then
  cal_line="$(jq -r --argjson now "$(date +%s)" '
    [.events[]? | select(.all_day != true) | select((.end_ms/1000) > $now)]
    | sort_by(.start_ms) | .[0] // empty
    | "\(.title)\t\(((.start_ms/1000) - $now) / 60 | floor)"' "$feed" 2>/dev/null)"
  if [[ -n "$cal_line" ]]; then
    cal_has=true
    cal_title="${cal_line%%$'\t'*}"
    cal_eta="${cal_line##*$'\t'}"
  fi
fi

# Agents: Omarchy keeps one usage record per coding agent (Claude Code,
# Codex, ...). Take the busiest ready one plus its tightest rate limit.
agents_json="[]"
usage_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage"
if [[ -d "$usage_dir" ]]; then
  agents_json="$(jq -cs '[ .[] | select(.ready == true)
    | {id, name, prompts: (.todayPrompts // 0), sessions: (.todaySessions // 0),
       limit: ([.limits[]?.percent] | max // 0),
       limitLabel: ((.limits // []) | max_by(.percent) | .label // "")} ]' "$usage_dir"/*.json 2>/dev/null || echo "[]")"
fi
# Live agent windows: Omarchy gives them one class. Claude Code and friends
# put a spinner glyph in the title while they work, so count those as busy.
agent_windows=0 agent_busy=0
windows="$(hyprctl clients -j 2>/dev/null | jq 'length' 2>/dev/null || echo 0)"
if wins="$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class == "org.omarchy.agent") | .title')"; then
  agent_windows="$(printf '%s\n' "$wins" | grep -c . || true)"
  agent_busy="$(printf '%s\n' "$wins" | grep -cE '^[◐◑◒◓✳✻✽✶✢⏺]' || true)"
fi

read -r load1 _ < /proc/loadavg
cores="$(nproc)"
hour="$(date +%-H)"

jq -cn \
  --arg cwd "$cwd" --arg repo "$repo" --arg branch "$branch" \
  --argjson inRepo "$in_repo" --argjson dirty "${dirty:-0}" --argjson untracked "${untracked:-0}" \
  --argjson ahead "${ahead:-0}" --argjson lastCommit "${last_commit:-0}" \
  --argjson battery "$battery" --argjson charging "$charging" \
  --argjson load "$load1" --argjson cores "$cores" --argjson hour "$hour" \
  --argjson calHas "$cal_has" --arg calTitle "$cal_title" --argjson calEta "${cal_eta:-0}" \
  --argjson agents "$agents_json" --argjson agentWindows "${agent_windows:-0}" --argjson agentBusy "${agent_busy:-0}" --argjson windows "${windows:-0}" \
  '{cwd:$cwd, repo:$repo, branch:$branch, inRepo:$inRepo, dirty:$dirty, untracked:$untracked,
    ahead:$ahead, lastCommit:$lastCommit, battery:$battery, charging:$charging,
    load:$load, cores:$cores, hour:$hour, now:(now|floor),
    calendar:{has:$calHas, title:$calTitle, eta:$calEta},
    agents:$agents, agentWindows:$agentWindows, agentBusy:$agentBusy, windows:$windows}'
