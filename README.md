# dotfiles

- `claude/`: Claude Code status line, settings and CLAUDE.md
- `ghostty/`: Ghostty terminal config (TokyoNight Night, JetBrainsMono Nerd Font)
- `zsh/`: .zshrc

## Install on a new computer

```bash
git clone https://github.com/jaylers/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

The status line needs `jq` (`brew install jq`).
The Ghostty config needs JetBrainsMono Nerd Font (`brew install --cask font-jetbrains-mono-nerd-font`).

## Claude rules (CLAUDE.md)

`install.sh` links `claude/CLAUDE.md` to `~/.claude/CLAUDE.md`.
Claude Code reads that file in every session, in any folder or worktree.
So the rules work everywhere. You do not need to copy them into each project.

To change a rule, edit `~/dotfiles/claude/CLAUDE.md`. New sessions use it.

If the rules stop working, check the link and make it again:

```bash
ls -l ~/.claude/CLAUDE.md
ln -sf ~/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
```
