# Omabuddy

A small, mostly useless companion for [Omarchy](https://omarchy.org/). It sits
in a corner of your screen, wears your theme, and has opinions about your day.

![Omabuddy in its corner, judging your terminal count](preview.png)

It notices:

- **The clock.** Sleepy before eight, hyped after lunch, zen in the evening.
- **Your work streak.** Ninety minutes without a break and it starts nagging you to stand up.
- **Git.** It follows the working directory of your focused terminal. A big
  uncommitted diff makes it worry, a commit makes it proud, a push makes it
  cheer. It reads your commit subjects too: five fixes in a row, a bare
  "wip", a subject over 72 characters or one made only of emoji all get a
  look. Forty untracked files or twenty dirty lines straight on `main` earn a
  comment.
- **Your machine.** Pegged CPUs make it sweat, a low battery makes it panic,
  twenty open windows overwhelm it. Plugging in is dinner, a full battery is
  a happy sigh, unplugging is a nervous glance.
- **The calendar.** Monday mornings and Friday afternoons have their own
  lines, a push after eleven at night gets called bold, and it wears a hat
  on Halloween, New Year's Day and its own birthday (the day you installed it).
- **You leaving.** Half an hour away, or a suspend, and it greets you when you
  are back and starts the work streak fresh.
- **Achievements.** First push of the day, ten commits in a day, and a week
  without a battery panic each get a block-character confetti burst.
- **Your calendar.** If [OmaCal](https://github.com/omacal) is installed it reads
  the same feed as the OmaCal bar widget and warns you ten minutes before a meeting.
- **Your coding agents.** Omarchy already tracks Claude Code, Codex, and
  friends. The buddy knows when an agent window is spinning, when it stops
  and wants you back, and when you are about to hit a rate limit.
- **Whatever you tell it.** Hooks for your shell, Claude Code, test runs and
  Omarchy itself report failed commands, finished builds, a new theme or an
  update (see [Hooks](#hooks)). And you can ask it things.

Three optional **senses** do more, each off until you switch it on in the
settings card:

- **Desktop.** A workspace-hopping spree, a burst of new windows, and
  fullscreen: while a fullscreen window has focus it fades and keeps quiet.
- **Devices.** The speaker muted or turned all the way up, the network
  dropping or coming back, a Bluetooth device connecting.
- **Music.** What's playing over MPRIS, and the same song on repeat.

It comes in four shapes, all made of block characters: the original **blob**,
a **cat** that wags its tail when it's happy and ignores some of your pokes, a
**ghost** that floats above its shadow and fades when it's sleepy, and a
**bot** with a blinking antenna. Each one has a few lines of its own.

Everything it says comes from `Quips.js`, a plain list of one-liners in four
voices that you can add to: **snarky** (the default), **polite**, **cheerful**
and **deadpan**. If you run a local [Ollama](https://ollama.com/), it can
improvise instead.

## Install

```bash
omarchy plugin add https://github.com/wirlen/omabuddy.git --enable
```

Then restart the shell once so the panel mounts:

```bash
omarchy restart shell
```

## Using it

| Do this | It does |
| --- | --- |
| Click it | Pokes it. It says something. Five pokes in a minute and it sulks for 45 seconds. |
| Drag it | Moves it. It snaps to the nearest corner and remembers. |
| Scroll on it | Grows or shrinks it. The size is remembered. |
| Right-click it | Opens the settings card: pick a buddy, a voice, how chatty it is, its size and corner, and whether Ollama writes its lines. Each pick takes effect straight away and the buddy says a line about it. Click anywhere else to close the card. |
| Middle-click it | Mutes or unmutes the speech bubble. |
| `omarchy-shell omabuddy listen` | Opens a text box beside it. Type, press Enter, and it answers (through Ollama if that's on). Esc or a click elsewhere closes it. Bind it to a key, or use "ask me something" on the settings card. |

From a terminal or a script:

```bash
omarchy-shell omabuddy say "build is green"
omarchy-shell omabuddy ask "how's my day going?"   # it answers in one line
omarchy-shell omabuddy listen           # open or close the ask box
omarchy-shell omabuddy event failed     # report an event (list below)
omarchy-shell omabuddy poke
omarchy-shell omabuddy mood proud       # any mood name from Mood.js, for 20 seconds
omarchy-shell omabuddy celebrate tenCommits   # confetti plus that achievement's line
omarchy-shell omabuddy state            # JSON of mood, streak, and sensors
omarchy-shell omabuddy set <key> <value>   # e.g. set buddy ghost, set tone deadpan
omarchy-shell omabuddy settings         # open or close the settings card
```

`say` puts any text in the bubble. `event` is the safer hook point: it takes
one of a fixed list of names and nothing else, so a script can make the
buddy react but can't put words in its mouth or in the Ollama prompt.

| Event | Reaction |
| --- | --- |
| `passed`, `failed` | A test run, build or CI result |
| `commandFailed`, `longCommandDone` | A shell command failed, or finished after a minute or more |
| `agentDone`, `agentWaiting` | A coding agent finished, or is waiting for you |
| `themeChanged`, `fontChanged`, `updated` | Omarchy changed the theme or font, or finished an update |
| `batteryLow` | Panic, and look at the battery now |
| `gitChanged` | No reaction of its own: it looks at git right away instead of on its next probe |

Lines are rationed so hooks and senses can't make it chatter. Anything you
didn't cause directly (the probe, senses, events, the chatter timer) stays
quiet within 8 seconds of the last line, when the same mood spoke in the last
90 seconds, or while a fullscreen window has focus; the face still changes.

## Hooks

Ready-made hooks live in `hooks/`. Each sends a single event name and
nothing else, in the background, so it never slows down what called it.

```bash
dir=~/.config/omarchy/plugins/wirlen.omabuddy/hooks

# Omarchy: theme, font, update, low battery (copies the file into ~/.config/omarchy/hooks)
omarchy hook install theme-set   $dir/omarchy/omabuddy-theme-set.sh
omarchy hook install font-set    $dir/omarchy/omabuddy-font-set.sh
omarchy hook install post-update $dir/omarchy/omabuddy-post-update.sh
omarchy hook install battery-low $dir/omarchy/omabuddy-battery-low.sh

# Shell: failed and long-running commands. Add to the END of ~/.bashrc (or ~/.zshrc):
source ~/.config/omarchy/plugins/wirlen.omabuddy/hooks/shell/omabuddy.bash   # or omabuddy.zsh

# Tests and builds: passed or failed, keeping the command's own exit status
~/.config/omarchy/plugins/wirlen.omabuddy/hooks/judge.sh npm test

# Git, per repo you trust (never as a global core.hooksPath)
cp $dir/git/post-commit.sh .git/hooks/post-commit
```

For Claude Code, add these to `hooks` in `~/.claude/settings.json`:

```json
"Stop":         [{ "hooks": [{ "type": "command", "command": "~/.config/omarchy/plugins/wirlen.omabuddy/hooks/claude/omabuddy.sh stop" }] }],
"Notification": [{ "hooks": [{ "type": "command", "command": "~/.config/omarchy/plugins/wirlen.omabuddy/hooks/claude/omabuddy.sh notification" }] }]
```

The shell hook stays quiet for everyday noise: a quick exit 1 (grep finding
nothing, a false test) isn't a failure, but exit 2 or more, or exit 1 after
3 seconds (a failed build or test), is. Ctrl-C, Ctrl-Z and broken pipes
never count. A minute-long command counts unless it was something you sit
in on purpose, like an editor, pager, ssh or a REPL. At most one event
every 10 seconds. The Omarchy hooks are small wrappers around
`hooks/omarchy/omabuddy.sh` in the plugin, so plugin updates reach them
without reinstalling. The Claude Code hook never reads the hook's input, so your
prompts and messages never reach it.

## Settings

Right-click the buddy for the settings card, set a key with
`omarchy-shell omabuddy set <key> <value>`, or edit the plugin's entry in
`~/.config/omarchy/shell.json`. Changes apply immediately. The Ollama URL and
model are text, so they stay on `set`: the card never takes keyboard focus.

| Key | Default | Meaning |
| --- | --- | --- |
| `corner` | `bottom-right` | `top-left`, `top-right`, `bottom-left`, `bottom-right` |
| `size` | `14` | Face font size in pixels, 8 to 48. Scrolling on the buddy sets this too. |
| `buddy` | `blob` | `blob`, `cat`, `ghost` or `bot` |
| `tone` | `snarky` | `snarky`, `polite`, `cheerful` or `deadpan` |
| `chattiness` | `12` | Minutes between unprompted lines |
| `muted` | `false` | Hide the speech bubble |
| `llm` | `off` | `ollama` to improvise lines with a local model |
| `ollamaUrl` | `http://localhost:11434` | Where Ollama listens |
| `ollamaModel` | `llama3.2` | Any model you have pulled |
| `allowRemoteLlm` | `false` | Ollama URLs are limited to this machine unless this is `true` |
| `probeSeconds` | `20` | How often it looks at git, battery, and load |
| `llmCooldown` | `30` | Seconds between Ollama-written lines, 5 to 600. A canned line fills the gap. Asking skips it. |
| `llmPerHour` | `40` | Most Ollama calls in any hour, asks included, 1 to 240 |
| `senseDesktop` | `false` | React to Hyprland: workspace hopping, window bursts, fullscreen |
| `senseDevices` | `false` | React to the speaker, the network and Bluetooth |
| `senseMusic` | `false` | React to what's playing over MPRIS |
| `installedOn` | set on first run | `YYYY-MM-DD`; the buddy's birthday |
| `stats` | written by the buddy | Today's commit and push counts and the last battery panic, for achievements |

Example entry:

```json
{ "id": "wirlen.omabuddy", "corner": "bottom-left", "llm": "ollama", "ollamaModel": "qwen2.5:3b" }
```

## Moods

`idle`, `sleepy`, `hyped`, `stretch`, `worried`, `proud`, `shipped`, `sweaty`,
`panic`, `zen`, `meeting`, `rationed`, `cooking`, `agentDone`, `poked`, `greeting`,
`welcomeBack`, `overwhelmed`, `cluttered`, `daring`, `grumpy`, `ignoring`,
`fixStreak`, `wipCommit`, `longSubject`, `emojiCommit`, `lateShip`, `plugged`,
`full`, `unplugged`, `monday`, `friday`, `birthday`, `firstPush`, `tenCommits`,
`calmWeek`, `thinking`, `asked`, `askBusy`, `passed`, `failed`, `commandFailed`,
`longCommandDone`, `agentWaiting`, `themeChanged`, `fontChanged`, `updated`,
`restless`, `speakerMuted`, `loud`, `offline`, `online`, `bluetooth`, `music`,
`onRepeat`. The rules live in `Mood.js`; the face for
each mood is a handful of numbers in the same file, and the costume for the
day is `Mood.costume()`. The critters themselves live in `Buddies.js`.

## Contributing lines

Open `Quips.js`, find the mood, add a line under the voice it belongs to.
Keep it short, kind, and in the voice of a small creature who lives in a
screen corner. Lines a particular critter would say (a cat, a ghost, a bot)
go in `flavor` at the bottom of the file. Tokens `{repo}`,
`{branch}`, `{dirty}`, `{hour}`, `{time}`, `{streak}`, `{battery}`, `{event}`, `{eta}`,
`{agent}`, `{prompts}`, `{limit}`, `{windows}`, `{untracked}`, `{subject}`,
`{fixes}`, `{commits}`, `{pushes}` and `{days}` are filled in, plus `{track}`
and `{artist}` while the music sense is on.

## How it works

One `panel` plugin with `keepLoaded: true`. A fullscreen transparent layer
window on the Top layer, input-masked to the buddy so the rest of the screen
clicks through. `scripts/probe.sh` runs every few seconds and prints a JSON
snapshot of the world. `Mood.js` turns that into a mood. `Face.qml` draws the mood as block-character
text art in the shell's monospace font, glowing in a theme colour read from the
active theme's `colors.toml`. No image assets, no daemons.

Plugin code changes need `omarchy restart shell` because the panel is kept
loaded across hot-reloads.

## Status and next steps

This is a fun side project, not a product. It works, it's stable on Omarchy 4,
and it will stay small on purpose. Things that would be fun to add, roughly in
order of how likely they are to happen:

- **Faster AI replies.** Ollama answers today take a few seconds. Keep the model
  warm, stream the first line, and let a short canned reaction show while the
  real one is on its way.
- **More senses.** Disk nearly full, updates pending, a mic left unmuted.
- **More critters and voices.** A fifth buddy, extra moods, a per-theme
  colour override, and packs of quips in other languages.

Ideas and quips are welcome as issues or pull requests. Keep it kind, keep
it short, keep it useless. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
maintainer notes, including the security and privacy rules every change has
to follow.

## Privacy and safety

- Everything runs as your user inside `omarchy-shell`, like every Omarchy plugin.
- The probe only reads: the focused window's process tree under `/proc` (to
  find your terminal's working directory), git state there (branch, change
  counts, the last commit's time and subject line, and how many of the last
  eight subjects start with "fix"), Hyprland's window
  list (the count, plus the titles of agent windows to spot a spinner),
  battery and load from sysfs, the clock, the OmaCal feed, and Omarchy's agent usage
  records. It runs git with hooks-free, config-safe flags so a freshly cloned
  repo cannot run code through its own `.git/config`.
- The optional senses are off until you switch them on, and read nothing
  while off. They read from models the shell already keeps; none of them
  spawns a process or opens a file. **Desktop** compares the names of
  Hyprland events (never their data, so no window titles) and reads whether
  the focused window is fullscreen (not merely maximized). **Devices** reads the default
  speaker's mute flag and volume, NetworkManager's connectivity state, and
  how many Bluetooth devices are connected (never their names). **Music**
  reads the playing track's title and artist, each clipped to 64 characters.
  Turning a sense on runs nothing else and changes nothing on your system.
- `event` takes only names from a fixed list, at most 32 characters, and
  carries no other data. The hooks in `hooks/` send nothing but that name:
  not your commands, their output, the directory, or Claude Code's hook
  input. `ask` text is clipped to 280 characters, with control characters
  removed, before anything else sees it.
- Nothing leaves the machine unless you set `llm` to `ollama`. Then each quip
  request posts the mood plus the fixed descriptions of the chosen buddy and
  voice (from `Buddies.js` and `Quips.js`), and a small JSON context, to
  `ollamaUrl`. When you ask it something, your question goes too (refused
  above 1,024 bytes by the script). Calls are rationed: one at a time, one
  improvised line per `llmCooldown` seconds, and at most `llmPerHour` calls in
  any hour. Exactly these context fields:
  repo name (not the path), branch, count of uncommitted changed lines, count
  of untracked files, the last commit's subject line, the fix-streak count,
  hour of day, day of week, the time as HH:MM, minutes of your current work
  streak, battery percent, number of open windows, next calendar event title
  and minutes until it, the busiest agent's name and prompt count, the highest
  agent limit percentage, today's commit and push counts and days since
  install from the buddy's own bookkeeping, and, only while the music sense
  is on, the playing track's title and artist.
- The URL must be `http` or `https` and must point at this machine
  (localhost, 127.x, or ::1) unless you also set `allowRemoteLlm` to `true`.
  That guard lives in the script itself, so a stray process flipping the
  setting over IPC can't quietly turn the buddy into a beacon.
- The probe gives up after 15 seconds (its whole process group is killed 2
  seconds after that), so a stalled network mount under your terminal can't
  wedge it.
- The probe is bounded in bytes, not just time. Every name, branch, commit
  subject and event title is clipped to 128 characters, the fix-streak count
  looks at eight subject lines within 4 KiB, git listings are counted for at most
  20,000 lines, each JSON document it parses (window list, calendar feed) is
  cut off at 1 MiB, each agent usage record at 64 KiB and at most 16 records,
  files are read without following symlinks, and a snapshot over 16 KiB is
  refused by the probe and dropped again by the panel. A hostile repo or an
  oversized record costs a bounded read, never a large allocation.
- Its own settings and your theme's colours are read the same way. The
  panel only watches `shell.json` and the theme's `colors.toml` for changes;
  `scripts/config.sh` reads them (`shell.json` up to 1 MiB, `colors.toml` up
  to 64 KiB), and hands back only this plugin's entry (at most 32 KiB) or the
  `name = "#hex"` colour lines (at most 64). These two files are often
  dotfile-manager symlinks, so they are resolved to their target first; the
  target must still be a regular file under the same caps.
- Nothing it learns is put on a command line, where any local user could
  read it in `/proc`. Repo paths, branch names, commit subjects, event titles
  and the Ollama prompt travel through pipes and the process environment
  (readable only by you): git runs from inside the repo, jq reads strings
  from its environment, and curl takes the request body on stdin.
- Every line it shows is rendered as plain text, never markup. That includes
  a commit subject quoted back at you.
- On its own, it writes only two keys in its own `shell.json` entry:
  `installedOn` and the `stats` counters. The settings card writes the keys
  you click (`buddy`, `tone`, `chattiness`, `muted`, `size`, `corner`, `llm`,
  `senseDesktop`, `senseDevices`, `senseMusic`), and nothing else. The ask box
  is the only part that takes keyboard focus, and only while it is open. Everything is read back as untrusted data: an unknown
  `buddy` or `tone` falls back to the default, never into the art or the
  quip tables.
- These are rules, not accidents. [CONTRIBUTING.md](CONTRIBUTING.md) spells
  out what a change may read and send, and how to report a vulnerability.

## License

MIT
