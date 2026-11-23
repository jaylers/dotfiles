#!/bin/bash
# Link the config in this repo into place
# Existing files are kept as <name>.backup
set -e
repo=$(cd "$(dirname "$0")" && pwd)

# link <file in repo> <target path>
link() {
  mkdir -p "$(dirname "$2")"
  [ -e "$2" ] && [ ! -L "$2" ] && mv "$2" "$2.backup"
  ln -sfn "$repo/$1" "$2"
  echo "linked $2"
}

# Claude Code
for f in statusline.sh settings.json CLAUDE.md; do
  link "claude/$f" ~/.claude/$f
done
link claude/themes ~/.claude/themes

# Ghostty
link ghostty/config.ghostty "$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"

# Zsh
link zsh/.zshrc ~/.zshrc
