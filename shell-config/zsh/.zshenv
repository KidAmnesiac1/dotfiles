# Zsh environment entrypoint (owned by dotfiles): keep fast/safe and source only env.

ZSH_SHELL_DIR="$HOME/.config/shells/zsh"

if [ -f "$ZSH_SHELL_DIR/env.zsh" ]; then
  . "$ZSH_SHELL_DIR/env.zsh"
fi
