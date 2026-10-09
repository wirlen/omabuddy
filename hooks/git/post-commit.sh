#!/usr/bin/env bash
# Git post-commit hook for one repo: make Omabuddy look at git right away
# instead of on its next probe. Copy it into a repo you trust:
#   cp ~/.config/omarchy/plugins/wirlen.omabuddy/hooks/git/post-commit.sh .git/hooks/post-commit
# Don't point a global core.hooksPath at this folder: that would replace
# every repo's own hooks.
set -u
command -v omarchy-shell >/dev/null 2>&1 || exit 0
omarchy-shell -q omabuddy event gitChanged >/dev/null 2>&1 &
exit 0
