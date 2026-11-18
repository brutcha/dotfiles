#!/usr/bin/env zsh
# Prepare an Emdash-created worktree from its base checkout.
# The project id and shared Devkit entries are substituted by corp-project.nix.

setopt nullglob
base="$HOME/git/@projectId@"
[ "$PWD" -ef "$base" ] && exit 0
cp "$base/.emdash.json" .emdash.json 2>/dev/null || true
[ -e "$base/.opencode" ] || [ -L "$base/.opencode" ] && ln -sfn "$base/.opencode" .opencode
ln -sfn "$base/.claude/settings.local.json" .claude/settings.local.json
if [ -d "$base/.devkit/personal" ]; then
  for p in .claude/.custom .claude/.custom-autoload .codex/.custom .codex/.custom-autoload; do
    [ -L "$p" ] && rm "$p"
  done
  for n in @devkitShared@; do
    [ -e "$base/.devkit/$n" ] || continue
    [ -e ".devkit/$n" ] && [ ! -L ".devkit/$n" ] && continue
    ln -sfn "$base/.devkit/$n" ".devkit/$n"
  done
  mkdir -p .claude/skills .agents/skills
  for d in "$base/.claude/skills/"*-custom; do
    [ -d "$d" ] || continue
    [ -e ".claude/skills/$(basename "$d")" ] || cp -r "$d" ".claude/skills/$(basename "$d")"
    [ -e ".agents/skills/$(basename "$d")" ] || cp -r "$d" ".agents/skills/$(basename "$d")"
  done
else
  mkdir -p .claude/skills .agents/skills
  for d in "$base/.claude/skills/"*-custom "$base/.claude/skills/"custom-*; do
    [ -d "$d" ] || continue
    ln -sfn "$d" ".claude/skills/$(basename "$d")"
    [ -e ".agents/skills/$(basename "$d")" ] || ln -sfn "$d" ".agents/skills/$(basename "$d")"
  done
  mkdir -p .codex
  ln -sfn "$base/.codex/.custom" .claude/.custom
  ln -sfn "$base/.codex/.custom-autoload" .claude/.custom-autoload
  ln -sfn "$base/.codex/.custom" .codex/.custom
  ln -sfn "$base/.codex/.custom-autoload" .codex/.custom-autoload
fi
