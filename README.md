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
