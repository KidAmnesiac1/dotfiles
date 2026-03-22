# Zsh completion: compinit and completion styles; keep this interactive-only.

autoload -Uz compinit

_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p -- "${_zcompdump:h}" 2>/dev/null || true

compinit -d "$_zcompdump"

if command -v kubectl >/dev/null; then
  (( $+functions[_kubectl] )) && compdef _kubectl k
fi
