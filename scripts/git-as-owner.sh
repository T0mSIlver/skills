#!/usr/bin/env bash
# git-as-owner.sh: a SessionStart hook that makes the session's commits the
# owner's, with no AI attribution. Run from a repo's .claude/settings.json
# (docs/install.md, "Commits carry the owner's name").
#
# 1. A clone whose git identity is Claude's (a cloud session's default)
#    commits as the owner. GitHub's squash merge adds "Co-authored-by:" for
#    every other commit author in a PR, so one Claude-authored branch commit
#    puts Claude on main even when every message is clean.
# 2. A commit-msg hook drops the trailers and footer the cloud harness asks
#    agents to add: Co-authored-by with Claude's noreply@anthropic.com
#    address, Claude-Session, and a line that is only "Generated with/by
#    Claude Code". Human co-authors and prose that mentions Claude stay.
#
# Leaves alone a person's own identity and a commit-msg hook it didn't write.
set -euo pipefail

owner_name="Tom Vaucourt"
owner_email="34662901+T0mSIlver@users.noreply.github.com"
marker="# installed by git-as-owner.sh (T0mSIlver/skills)"

cd "${CLAUDE_PROJECT_DIR:-.}" 2> /dev/null || exit 0
git rev-parse --git-dir > /dev/null 2>&1 || exit 0

case "$(git config user.email || true)" in
  noreply@anthropic.com | "")
    git config --local user.name "$owner_name"
    git config --local user.email "$owner_email"
    ;;
esac

# A hooks directory set outside this repo's config is shared with other repos.
if [ -n "$(git config core.hooksPath || true)" ] && [ -z "$(git config --local core.hooksPath || true)" ]; then
  echo "git-as-owner: core.hooksPath is set outside this repo; AI trailers won't be stripped" >&2
  exit 0
fi
hooks=$(git rev-parse --git-path hooks)
hook="$hooks/commit-msg"
if [ -e "$hook" ] && ! grep -qxF "$marker" "$hook"; then
  echo "git-as-owner: $hook exists and isn't mine; AI trailers won't be stripped" >&2
  exit 0
fi
mkdir -p "$hooks"
# Written aside and moved, so a concurrent run never sees a half-written hook.
cat > "$hook.git-as-owner.$$" << EOF
#!/bin/sh
$marker
# Drops AI attribution lines; git removes the blank lines left behind.
msg="\$1"
grep -viE '^[[:space:]]*(co-authored-by:[^<]*<noreply@anthropic\\.com>|claude-session:)|^[^[:alnum:]]*generated (with|by) \\[?claude code\\]?[^[:alnum:]]*(\\(https?://[^)]*\\)[^[:alnum:]]*)?\$' "\$msg" > "\$msg.git-as-owner" || true
mv -f "\$msg.git-as-owner" "\$msg"
EOF
chmod +x "$hook.git-as-owner.$$"
mv -f "$hook.git-as-owner.$$" "$hook"
