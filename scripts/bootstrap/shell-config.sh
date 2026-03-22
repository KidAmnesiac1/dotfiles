#!/usr/bin/env bash
set -e

source "$(dirname "$0")/lib.sh"

usage() {
  # Print CLI usage/help text.
  cat <<'EOF'
Usage: scripts/bootstrap/shell-config.sh [--shell auto|bash|zsh|both]

Stows shell entrypoint dotfiles from ./shell-config into $HOME, backing up conflicts.

Defaults to --shell auto (based on $SHELL).
EOF
}

detect_shell() {
  # Determine which shell config to install based on $SHELL.
  case "${SHELL:-}" in
    */zsh) echo "zsh" ;;
    */bash) echo "bash" ;;
    *) echo "both" ;;
  esac
}

backup_and_stow_package() {
  # Backup conflicting targets in $HOME then stow a single shell-config package.
  local dotfiles_root="$1"
  local pkg="$2"

  if [ "$pkg" = "bash" ]; then
    maybe_backup_conflict "$HOME/.bashrc" "$dotfiles_root/shell-config/bash/.bashrc"
    maybe_backup_conflict "$HOME/.bash_profile" "$dotfiles_root/shell-config/bash/.bash_profile"
    stow -d shell-config -t "$HOME" bash
    return 0
  fi

  if [ "$pkg" = "zsh" ]; then
    maybe_backup_conflict "$HOME/.zshenv" "$dotfiles_root/shell-config/zsh/.zshenv"
    maybe_backup_conflict "$HOME/.zshrc" "$dotfiles_root/shell-config/zsh/.zshrc"
    stow -d shell-config -t "$HOME" zsh
    return 0
  fi

  echo "Unknown shell package: $pkg" >&2
  return 2
}

main() {
  # Parse args, validate environment, then install shell entrypoint config.
  local shell="auto"

  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --shell) shell="${2:-}"; shift 2 ;;
      --shell=*) shell="${1#*=}"; shift 1 ;;
      *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
  done

  if [ "$shell" = "auto" ]; then
    shell="$(detect_shell)"
  fi

  if [ ! -d shell-config ] || [ -z "$(find shell-config -mindepth 1 -print -quit 2>/dev/null)" ]; then
    echo "No dotfiles found under shell-config/; skipping shell config."
    return 0
  fi

  if ! command -v stow >/dev/null; then
    echo "Stow is missing; install it and rerun bootstrap."
    return 0
  fi

  local dotfiles_root
  dotfiles_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

  case "$shell" in
    bash) backup_and_stow_package "$dotfiles_root" bash ;;
    zsh) backup_and_stow_package "$dotfiles_root" zsh ;;
    both)
      backup_and_stow_package "$dotfiles_root" bash
      backup_and_stow_package "$dotfiles_root" zsh
      ;;
    *)
      echo "Invalid --shell value: $shell" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
