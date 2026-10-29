# Zsh interactive entrypoint (owned by dotfiles): load modular interactive config.

ZSH_SHELL_DIR="$HOME/.config/shells/zsh"

if [ -f "$ZSH_SHELL_DIR/init.zsh" ]; then
  . "$ZSH_SHELL_DIR/init.zsh"
fi
