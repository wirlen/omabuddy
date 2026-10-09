# Omabuddy for bash: a failed command or one that ran a minute or longer gets
# a reaction. Source it at the END of ~/.bashrc, after any prompt setup
# (starship and friends), so it sees each command's exit status first:
#   source ~/.config/omarchy/plugins/wirlen.omabuddy/hooks/shell/omabuddy.bash
# Only an event name is sent: never the command, its output, or the directory.
# At most one event every 10 seconds, sent in the background so the prompt
# never waits.
#
# What counts, so everyday use stays quiet:
#   commandFailed    exit 2 or more (not found, misuse, crashes), or exit 1
#                    after 3 s or more (a build or test that failed). A quick
#                    exit 1 is grep finding nothing or a false test, not a
#                    failure. Ctrl-C (130), SIGPIPE (141), Ctrl-Z (148) never.
#   longCommandDone  a minute or more, unless it was an editor, pager, shell,
#                    REPL or other program you sit in (see _omabuddy_sit_in).

[[ $- == *i* ]] || return 0
command -v omarchy-shell >/dev/null 2>&1 || return 0

_omabuddy_started=""
_omabuddy_last_sent=0

# Programs you stay in for a while on purpose: finishing one is not news.
_omabuddy_sit_in() {
  case "${1##*/}" in
    vi|vim|nvim|nano|emacs|hx|helix|micro|less|more|most|man|info|ssh|mosh|tmux|zellij|screen|\
    top|htop|btop|watch|journalctl|tail|claude|codex|aider|python|python3|ipython|node|bun|deno|irb|\
    psql|mysql|sqlite3|lazygit|lazydocker|yazi|ranger|nnn|fzf|bash|zsh|fish|sh) return 0 ;;
  esac
  return 1
}

_omabuddy_precmd() {
  local status=$? event="" words
  # PS0 stamps _omabuddy_started when a command line runs; an empty Enter
  # leaves it unset, so a stale exit status is never reported twice.
  [[ -n "$_omabuddy_started" ]] || return "$status"
  local took=$(( EPOCHSECONDS - _omabuddy_started ))
  _omabuddy_started=""
  if (( status >= 2 && status != 130 && status != 141 && status != 148 )) || (( status == 1 && took >= 3 )); then
    event=commandFailed
  elif (( status == 0 && took >= 60 )); then
    # The command line stays in this shell; only its verdict leaves it.
    read -ra words <<<"$(fc -ln -1 2>/dev/null)"
    while [[ "${words[0]-}" =~ ^(sudo|env|time|nice|command|exec|[A-Za-z_][A-Za-z0-9_]*=.*)$ ]]; do words=("${words[@]:1}"); done
    # Unknown (history off, or a line history skipped): stay quiet.
    [[ -n "${words[0]-}" ]] && ! _omabuddy_sit_in "${words[0]}" && event=longCommandDone
  fi
  if [[ -n "$event" ]] && (( EPOCHSECONDS - _omabuddy_last_sent >= 10 )); then
    _omabuddy_last_sent=$EPOCHSECONDS
    ( omarchy-shell -q omabuddy event "$event" >/dev/null 2>&1 & )
  fi
  return "$status"
}

# Arithmetic in PS0 runs in this shell, so the stamp survives; it prints nothing.
PS0="${PS0-}"'${_omabuddy_started:0:$((_omabuddy_started=EPOCHSECONDS, 0))}'
if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
  PROMPT_COMMAND=(_omabuddy_precmd "${PROMPT_COMMAND[@]}")
else
  PROMPT_COMMAND="_omabuddy_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
