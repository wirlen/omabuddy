# Contributing and maintainer notes

Omabuddy is a fun side project. It is also code that runs unsandboxed inside
`omarchy-shell`, as your user, on every desktop that installs it. Those two
facts shape everything below: keep it light, keep it small, and never get
casual about what it can see or do.

## Expectations

- No support promises and no release schedule. Issues may sit for a while.
- Pull requests are welcome. Small ones get merged faster.
- Be kind in issues and in quips. That is the whole code of conduct.

## Security and privacy are non-negotiable

These rules apply to every change, however small:

- **Local by default, always.** Nothing leaves the machine unless the user
  explicitly turns on a feature that says so in the README. Today that is
  only the Ollama mode, and it only speaks to a URL the user set.
- **Least reading.** The probe reads exactly what a mood needs and nothing
  more. Don't add sensors that read file contents, clipboard, keystrokes,
  browser state, or anything under another user's home.
- **Treat every input as hostile.** Window titles, branch names, calendar
  titles, agent records, model output, and files in the focused directory are
  all untrusted. Build JSON with `jq --arg`, render text as plain text, and
  never pass any of it to a shell unquoted.
- **Run tools defensively.** Git runs with every repo-config command hook it
  could reach switched off: `core.fsmonitor`, the pager and `diff.external`
  in the `g()` wrapper, plus `--no-ext-diff --no-textconv` on the diff call
  and `log.showSignature=false --no-show-signature` on the log call so
  `gpg.program` is never invoked (see `scripts/probe.sh`). Any new git call
  or external tool needs the same thinking: what can a hostile directory make
  it do?
- **Parse URLs like an attacker wrote them.** The loopback check in
  `scripts/ollama.sh` refuses userinfo (`localhost@evil`) and matches only
  `localhost`, `127.x.y.z` and `::1`, never a prefix. Keep it that strict.
- **Bound every input in bytes.** Anything read from a network endpoint, a
  file, or a tool's output is capped producer-side before it is parsed and
  rejected at max+1 (see `scripts/ollama.sh`: 64 KiB; `scripts/probe.sh`:
  `read_capped`, `run_capped`, `clip`, and `out_max`). Strings that reach the
  panel are clipped, lists are capped in length, files are opened without
  following symlinks, and the panel drops any snapshot over its own cap
  again. A time limit alone is not a cap.
- **No new daemons, no new packages, no network listeners.** If a feature
  needs one, it probably belongs in a separate project the plugin can talk to.
- **No secrets in settings.** Settings live in `shell.json` in plain text.
  Don't add anything that would need an API key there.
- **Say what you send.** Any change to what a feature reads or transmits
  must update the "Privacy and safety" section of the README in the same PR.

Found a vulnerability? Use GitHub's private vulnerability reporting on this
repository, or email the maintainer, rather than opening a public issue.

## What gets merged

- **Quips.** The easiest contribution. One line, under 90 characters,
  quoting untrusted tokens like `{subject}` or `{branch}` is fine because
  the bubble is plain text.
  lowercase, kind, ideally in both tones. No politics, no jokes at a group's
  expense, no advice longer than a sentence.
- **Moods and faces.** Come with a screenshot and a one-line reason the
  buddy would feel that way.
- **Sensors.** Only with a clear privacy story that passes the rules above.
- **Bug fixes.** Always.

## What won't get merged

- Anything that turns it into a productivity tool. Useless is a feature.
- Features on by default that read more or send more than today.
- Large refactors without a bug or feature behind them.

## Testing a change

1. Edit files in `~/.config/omarchy/plugins/wirlen.omabuddy/`.
2. Run `omarchy restart shell`. The panel is kept loaded, so hot-reload alone
   does not pick up changes.
3. Force moods with `omarchy-shell omabuddy mood <name>` and say lines with
   `omarchy-shell omabuddy say "..."`.
4. Watch for warnings: `journalctl --user -f | grep -i omabuddy`.
5. Run `scripts/probe.sh | jq .` directly to check sensor output.
6. For anything touching the probe, test against a repo you don't trust.

## Versioning

Bump `version` in `manifest.json` on any user-visible change. `omarchy plugin
update` shows users a diff before applying, and the number helps them decide.

## License

MIT. By contributing you agree your changes are MIT too.
