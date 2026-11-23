#!/bin/bash
# Link the Claude Code config in this repo into ~/.claude
# Existing files are kept as <name>.backup
set -e
repo=$(cd "$(dirname "$0")" && pwd)
mkdir -p ~/.claude
for f in statusline.sh settings.json CLAUDE.md; do
  target=~/.claude/$f
  [ -e "$target" ] && [ ! -L "$target" ] && mv "$target" "$target.backup"
  ln -sfn "$repo/claude/$f" "$target"
  echo "linked $target"
done
