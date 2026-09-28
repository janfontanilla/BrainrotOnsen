#!/usr/bin/env bash
# Stop hook: block ending a turn when project files changed after PROGRESS.md.
input=$(cat)

# Already blocked once this stop cycle; let Claude stop to avoid a loop.
if printf '%s' "$input" | grep -q '"stop_hook_active" *: *true'; then
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" || exit 0
[ -f PROGRESS.md ] || exit 0

newer=$(find src default.project.json wally.toml rokit.toml -type f -newer PROGRESS.md 2>/dev/null | head -5 | tr '\n' ' ')

if [ -n "$newer" ]; then
  printf '{"decision":"block","reason":"Project files changed after PROGRESS.md was last updated (%s). Update PROGRESS.md before stopping: tick finished items, update Current phase and Last updated, add a dated line to the Log, and refresh Blockers."}\n' "$newer"
fi
exit 0
