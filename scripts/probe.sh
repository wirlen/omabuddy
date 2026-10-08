#!/usr/bin/env bash
# Omabuddy sensor probe. Prints one JSON object describing the world the
# buddy lives in: the focused terminal's working directory and its git
# state, battery, CPU load, and the hour. Runs every few seconds from the
# panel, so it stays cheap and never blocks on anything.
#
# Everything it reads is untrusted and everything it reads is bounded. Each
# string it keeps is clipped, each file and tool output it parses is cut off
# producer-side at max+1 bytes and thrown away if it reaches that, and the
# final snapshot is refused rather than printed if it grows past out_max.
# Time is bounded by the panel (timeout -k 2 15); bytes are bounded here.
#
# Nothing it learns goes on a command line. /proc/<pid>/cmdline is readable
# by every local user, so paths, names, titles and subjects travel through
# pipes, the environment (readable only by you), and builtins: git runs from
# inside the repo instead of being handed its path, and the snapshot is
# assembled by jq from the environment.
set -u

. "${BASH_SOURCE[0]%/*}/lib.sh" || exit 1   # stderr cap, read_capped, run_capped

str_max=128        # chars kept of any name, branch or title
json_max=1048576   # bytes of any single JSON document parsed (hyprctl, feeds)
record_max=65536   # bytes of one agent usage record
records_max=16     # agent usage records looked at
lines_max=20000    # git output lines counted before we stop caring
out_max=16384      # bytes of the snapshot itself

clip() { printf '%s' "${1:0:${2:-$str_max}}"; }

pid="$(run_capped "$json_max" hyprctl activewindow -j | jq -r '.pid // empty' 2>/dev/null)"
pid="$(clip "$pid" 16)"
cwd=""
if [[ "$pid" =~ ^[0-9]+$ ]]; then
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

# The focused directory may be a repo you just cloned and have not read. A
# repo's own .git/config can name commands to run (core.fsmonitor on status
# and diff, diff.external and diff.*.textconv on diff, gpg.program on log
# when log.showSignature is set and a commit carries a signature header), so
# every call switches those off; -c wins over repo config. Nothing here needs
# hooks, pagers, signatures, or external tools.
g() { git -c core.fsmonitor=false -c core.pager=cat -c diff.external= -c log.showSignature=false "$@"; }
# git in a directory without putting the directory on git's command line.
gin() { local dir="$1"; shift; (cd -- "$dir" 2>/dev/null && g "$@"); }

# Only counts and clipped names are kept. The diff and ls-files listings are
# streamed through head so a repo with a million files costs a bounded read
# and never a buffered one; the counts saturate at lines_max, which is
# already "a lot" as far as a mood is concerned. Paths are bounded by the
# kernel (PATH_MAX); a hostile HEAD file can be any length, so branch is
# clipped.
in_repo=false branch="" dirty=0 untracked=0 ahead=0 last_commit=0 repo="" subject="" fix_streak=0
if [[ -n "$cwd" ]] && top="$(gin "$cwd" rev-parse --show-toplevel 2>/dev/null | head -c 4097)" && [[ -d "$top" ]]; then
  in_repo=true
  repo="$(clip "${top##*/}")"
  branch="$(clip "$(gin "$top" rev-parse --abbrev-ref HEAD 2>/dev/null | head -c "$((str_max * 4))")")"
  dirty="$(gin "$top" diff --no-ext-diff --no-textconv --numstat HEAD 2>/dev/null | head -n "$lines_max" | awk '{a+=$1; d+=$2} END {print a+d+0}')"
  untracked="$(gin "$top" ls-files --others --exclude-standard 2>/dev/null | head -n "$lines_max" | wc -l)"
  ahead="$(gin "$top" rev-list --count '@{u}..HEAD' 2>/dev/null | head -c 32 || echo 0)"
  last_commit="$(gin "$top" log -1 --no-show-signature --format=%ct 2>/dev/null | head -c 32 || echo 0)"
  # The commit subject is whatever the author typed, so it is clipped like a
  # branch name. The streak is how many of the last eight subjects in a row
  # start with "fix": eight lines of at most 512 bytes each are looked at.
  subject="$(clip "$(gin "$top" log -1 --no-show-signature --format=%s 2>/dev/null | head -c "$((str_max * 4))" | tr -d '\n')")"
  fix_streak="$(gin "$top" log -8 --no-show-signature --format=%s 2>/dev/null | head -n 8 | head -c 4096 \
    | awk 'tolower($0) ~ /^(fix|fixes|fixed|fixup|hotfix)([^a-z]|$)/ {n++; next} {exit} END {print n+0}')"
fi

battery=-1 charging=false
for bat in /sys/class/power_supply/BAT*; do
  [[ -r "$bat/capacity" ]] || continue
  battery="$(head -c 8 "$bat/capacity")"
  case "$(head -c 16 "$bat/status")" in Charging|Full) charging=true ;; esac
  break
done

# Calendar: the OmaCal plugin's feed, if OmaCal is installed. Next event that
# has not ended yet, minutes until it starts (negative while ongoing). Event
# titles come from whoever sent the invite, so the title is clipped.
cal_title="" cal_eta=0 cal_has=false
feed="${XDG_STATE_HOME:-$HOME/.local/state}/omacal/upcoming.json"
cal_line="$(read_capped "$feed" "$json_max" | jq -r --argjson now "$(date +%s)" --argjson n "$str_max" '
  [.events[]? | select(.all_day != true) | select((.end_ms/1000) > $now)]
  | sort_by(.start_ms) | .[0] // empty
  | "\(.title | tostring | .[:$n])\t\(((.start_ms/1000) - $now) / 60 | floor)"' 2>/dev/null | head -c "$((str_max * 4 + 32))")"
if [[ -n "$cal_line" ]]; then
  cal_has=true
  cal_title="${cal_line%%$'\t'*}"
  cal_eta="${cal_line##*$'\t'}"
fi

# Agents: Omarchy keeps one usage record per coding agent (Claude Code,
# Codex, ...). Take the busiest ready one plus its tightest rate limit. At
# most records_max records of record_max bytes each are read; a record that
# is larger, a symlink, or not a regular file is skipped, and the list that
# reaches the panel is at most eight entries of clipped strings and numbers.
agents_json="[]"
usage_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage"
if [[ -d "$usage_dir" ]]; then
  agents_json="$(
    n=0
    for f in "$usage_dir"/*.json; do
      (( n++ >= records_max )) && break
      read_capped "$f" "$record_max" && echo
    done | jq -cs --argjson n "$str_max" '[ .[] | objects | select(.ready == true)
      | {id: (.id | tostring | .[:$n]), name: (.name | tostring | .[:$n]),
         prompts: ((.todayPrompts | numbers) // 0), sessions: ((.todaySessions | numbers) // 0),
         limit: ([.limits[]?.percent | numbers] | max // 0),
         limitLabel: (([.limits[]? | select(.percent | numbers)] | max_by(.percent) | .label // "") | tostring | .[:$n])}
      ] | .[:8]' 2>/dev/null | head -c "$out_max")"
  [[ "$agents_json" == \[* ]] || agents_json="[]"
fi
# Live agent windows: Omarchy gives them one class. Claude Code and friends
# put a spinner glyph in the title while they work, so count those as busy.
# The window list is parsed once, under the same byte cap as every other
# document, and only two counts leave jq.
agent_windows=0 agent_busy=0 windows=0
counts="$(run_capped "$json_max" hyprctl clients -j | jq -r '
  [.[] | select(.class == "org.omarchy.agent") | .title | tostring] as $t
  | "\(length)\t\($t | length)\t\([$t[] | select(test("^[◐◑◒◓✳✻✽✶✢⏺]"))] | length)"' 2>/dev/null | head -c 64)"
if [[ "$counts" =~ ^([0-9]+)$'\t'([0-9]+)$'\t'([0-9]+)$ ]]; then
  windows="${BASH_REMATCH[1]}" agent_windows="${BASH_REMATCH[2]}" agent_busy="${BASH_REMATCH[3]}"
fi

read -r load1 _ < /proc/loadavg
cores="$(nproc)"
hour="$(date +%-H)"
dow="$(date +%u)"   # 1 = Monday .. 7 = Sunday

# Every --argjson below must be a number or the whole snapshot is lost.
num() { [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] && printf '%s' "$1" || printf '%s' "$2"; }
battery="$(num "$battery" -1)"; cal_eta="$(num "$cal_eta" 0)"; load1="$(num "$load1" 0)"
dirty="$(num "$dirty" 0)"; untracked="$(num "$untracked" 0)"; ahead="$(num "$ahead" 0)"
last_commit="$(num "$last_commit" 0)"; cores="$(num "$cores" 1)"; hour="$(num "$hour" 12)"; dow="$(num "$dow" 1)"
fix_streak="$(num "$fix_streak" 0)"
windows="$(num "$windows" 0)"; agent_windows="$(num "$agent_windows" 0)"; agent_busy="$(num "$agent_busy" 0)"

# Strings (and the agent list) reach jq through its environment, not its
# arguments; only counts, flags and the clock are arguments.
out="$(OB_CWD="$cwd" OB_REPO="$repo" OB_BRANCH="$branch" OB_SUBJECT="$subject" OB_CAL_TITLE="$cal_title" OB_AGENTS="$agents_json" \
  jq -cn --argjson fixStreak "$fix_streak" \
  --argjson inRepo "$in_repo" --argjson dirty "$dirty" --argjson untracked "$untracked" \
  --argjson ahead "$ahead" --argjson lastCommit "$last_commit" \
  --argjson battery "$battery" --argjson charging "$charging" \
  --argjson load "$load1" --argjson cores "$cores" --argjson hour "$hour" --argjson dow "$dow" \
  --argjson calHas "$cal_has" --argjson calEta "$cal_eta" \
  --argjson agentWindows "$agent_windows" --argjson agentBusy "$agent_busy" --argjson windows "$windows" \
  '{cwd:env.OB_CWD, repo:env.OB_REPO, branch:env.OB_BRANCH, inRepo:$inRepo, dirty:$dirty, untracked:$untracked,
    ahead:$ahead, lastCommit:$lastCommit, subject:env.OB_SUBJECT, fixStreak:$fixStreak,
    battery:$battery, charging:$charging,
    load:$load, cores:$cores, hour:$hour, dow:$dow, now:(now|floor),
    calendar:{has:$calHas, title:env.OB_CAL_TITLE, eta:$calEta},
    agents:(env.OB_AGENTS | fromjson), agentWindows:$agentWindows, agentBusy:$agentBusy, windows:$windows}')" || exit 1
# The panel refuses anything over out_max as well; this is the producer side.
(( $(printf '%s' "$out" | wc -c) <= out_max )) || { echo "omabuddy probe: snapshot over $out_max bytes, dropped" >&2; exit 1; }
printf '%s\n' "$out"
