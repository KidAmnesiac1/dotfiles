# Bash environment: exports and PATH that should be safe/fast; avoid aliases, shopt/set, and tool init.

# Prefer Neovim as the default editor so CLI tools respect it.
export EDITOR="nvim"
export VISUAL="$EDITOR"

# Add a personal bin directory early on the PATH.
export PATH="$HOME/bin:$PATH"

# Per-user tools (uv, and installers that default to ~/.local/bin) live here.
# Add it once, so installers don't need to append PATH lines to the rc files.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Load user-specific secrets if present (not tracked in git).
_dotfiles_env_local="$HOME/.env.local"
if [ -f "$_dotfiles_env_local" ]; then
  set -a
  . "$_dotfiles_env_local"
  set +a
fi
unset _dotfiles_env_local

# Ensure starship uses the config installed by these dotfiles.
if [ -z "${STARSHIP_CONFIG:-}" ]; then
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
fi
