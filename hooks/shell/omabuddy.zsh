# Omabuddy for zsh: a failed command or one that ran a minute or longer gets
# a reaction. Source it from ~/.zshrc:
#   source ~/.config/omarchy/plugins/wirlen.omabuddy/hooks/shell/omabuddy.zsh
# Only an event name is sent: never the command, its output, or the directory.
# At most one event every 10 seconds, sent in the background so the prompt
# never waits. The same rules as omabuddy.bash decide what counts: exit 2 or
# more, or exit 1 after 3 s, is a failure (never Ctrl-C, SIGPIPE or Ctrl-Z),
# and a minute-long run counts unless it was a program you sit in.

[[ -o interactive ]] || return 0
(( $+commands[omarchy-shell] )) || return 0
zmodload zsh/datetime
autoload -Uz add-zsh-hook

typeset -g _omabuddy_started="" _omabuddy_first="" _omabuddy_last_sent=0

_omabuddy_sit_in() {
  case "${1:t}" in
    vi|vim|nvim|nano|emacs|hx|helix|micro|less|more|most|man|info|ssh|mosh|tmux|zellij|screen|\
    top|htop|btop|watch|journalctl|tail|claude|codex|aider|python|python3|ipython|node|bun|deno|irb|\
    psql|mysql|sqlite3|lazygit|lazydocker|yazi|ranger|nnn|fzf|bash|zsh|fish|sh) return 0 ;;
  esac
  return 1
}

_omabuddy_preexec() {
  _omabuddy_started=$EPOCHSECONDS
  # The command line stays in this shell; only its verdict leaves it.
  local -a words=(${(z)1})
  while [[ "${words[1]-}" =~ '^(sudo|env|time|nice|command|exec|[A-Za-z_][A-Za-z0-9_]*=.*)$' ]]; do shift words; done
  _omabuddy_first="${words[1]-}"
}
_omabuddy_precmd() {
  local exit_status=$? event=""
  [[ -n "$_omabuddy_started" ]] || return
  local took=$(( EPOCHSECONDS - _omabuddy_started ))
  _omabuddy_started=""
  if (( exit_status >= 2 && exit_status != 130 && exit_status != 141 && exit_status != 148 )) || (( exit_status == 1 && took >= 3 )); then
    event=commandFailed
  elif (( exit_status == 0 && took >= 60 )) && [[ -n "$_omabuddy_first" ]] && ! _omabuddy_sit_in "$_omabuddy_first"; then
    event=longCommandDone
  fi
  if [[ -n "$event" ]] && (( EPOCHSECONDS - _omabuddy_last_sent >= 10 )); then
    _omabuddy_last_sent=$EPOCHSECONDS
    ( omarchy-shell -q omabuddy event "$event" >/dev/null 2>&1 & ) 2>/dev/null
  fi
}

add-zsh-hook preexec _omabuddy_preexec
# First in line, so it sees the command's exit status before other hooks run.
precmd_functions=(_omabuddy_precmd ${precmd_functions:#_omabuddy_precmd})
