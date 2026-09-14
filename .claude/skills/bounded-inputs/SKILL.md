---
name: bounded-inputs
description: Pre-push security audit for this plugin against the Omarchy marketplace reviewer's standard. Use before every push, before replying on the marketplace issue, and whenever scripts/, *.qml, README privacy text, or the manifest change. Triggers - push, release, bump version, marketplace, security review, HANCORE, baseline, unbounded, byte cap.
---

# Bounded inputs: pass the marketplace security review before pushing

The marketplace reviewer applies one rule to every line: **an input bounded in
time is not bounded**. Every byte the plugin reads from a file, a tool, or the
network must have a producer-side cap, be rejected at max+1, and be clipped
again before it reaches the long-lived Quickshell process. They cite exact
line ranges and re-review the exact commit SHA, so each push must be clean.

## Workflow

1. Run the deterministic audit from the repo root. It must print `clean`.

   ```sh
   .claude/skills/bounded-inputs/audit.sh
   ```

   A finding the rules cannot see through (the cap lives on another line)
   is silenced with a comment `# bounded: <reason>` on that line or the one
   above. The reason is for the reviewer as much as the script.

2. Walk the semantic checklist below over the diff. The script catches
   shapes; this catches meaning.

3. Confirm the paperwork the reviewer also checks:
   - `manifest.json` version bumped on any user-visible change.
   - README "Privacy and safety" describes every read, every cap, every send.
   - CONTRIBUTING rules updated if a new pattern was introduced.

4. Commit, push, then reply on the marketplace issue with the **full 40-char
   SHA**, one bullet per commit naming file and mechanism, and a request for
   a fresh baseline. See "Replying" below.

## Semantic checklist

For every `$( ... )`, `read`, `<`, `cat`, `jq <file>`, `curl`, and every
`StdioCollector`, answer these in the code comment next to it:

- **Who writes this input?** A hostile repo, a calendar invite, a window
  title, a model, another plugin. Nothing is trusted, including our own
  state files, because the reviewer does not accept "same user" as a bound.
- **What bounds the bytes?** `head -c max+1` on a pipe, `read_capped` on a
  file, `--max-filesize` plus `head -c` on curl, `.[:n]` inside jq,
  `clip` on a string. A `timeout` is not an answer.
- **What happens at max+1?** Rejected whole, never truncated-and-used.
  Truncated JSON must fail to parse, and the parse failure must keep the
  previous good state.
- **What bounds the count?** Files in a directory, array entries, lines
  listed. Loops over globs need a ceiling.
- **Symlinks?** Files under any state dir are opened with `-L` refused and
  `-f` required before reading.
- **Process tree?** Anything spawned from QML runs under `timeout -k 2 N`
  so the whole process group is signalled and then killed.
- **Consumer side?** The QML collector drops anything over its cap before
  `JSON.parse`, and checks the parsed value is a plain object.
- **Repo config?** New git calls disable fsmonitor, pager, external diff,
  textconv, and signature verification, as `g()` in the probe does.
- **Shell?** Untrusted strings never reach a shell unquoted, never get
  spliced into a jq filter (use `--arg`), and never get `eval`ed.

## Replying on the marketplace issue

The reviewer re-reviews the exact SHA the issue body points at. Update the
issue body's `security-baseline-refresh` marker to the new SHA, then post:

- One line: what was fixed, at which SHA.
- One bullet per commit: file, mechanism, numbers (cap sizes).
- "Requesting a fresh baseline at `<sha>`."

Keep it factual. Do not argue the threat model; they grade against the
checklist, not the risk.
