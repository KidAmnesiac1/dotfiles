#!/usr/bin/env bash
set -e

# If invoked via `sh`, we may be running bash in POSIX mode (macOS `/bin/sh`) or a shell that can't
# parse bash features used by this repo (arrays, process substitution). Re-exec under full bash.
if [ -n "${BASH_VERSION:-}" ]; then
  if shopt -oq posix; then
    exec bash "$0" "$@"
  fi
else
  exec bash "$0" "$@"
fi

echo "Bootstrapping dotfiles..."

source "$(dirname "$0")/scripts/bootstrap/lib.sh"

if [[ "$OSTYPE" == "darwin"* ]]; then
  command -v brew >/dev/null || \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew bundle
elif command -v apt >/dev/null; then
  xargs -a apt.txt sudo apt install -y
elif command -v yum >/dev/null; then
  sudo yum install -y yum-plugin-copr
  # Enable COPR for packages like lazygit.
  sudo yum copr enable -y atim/lazygit
  grep -v '^tree-sitter-cli$' apt.txt | xargs sudo yum install -y
  # tree-sitter-cli is published via npm for yum/dnf.
  sudo yum install -y nodejs npm
  sudo npm install -g tree-sitter-cli
elif command -v dnf >/dev/null; then
  sudo dnf install -y dnf-plugins-core
  # Enable COPR for packages like lazygit.
  sudo dnf copr enable -y atim/lazygit
  grep -v '^tree-sitter-cli$' apt.txt | xargs sudo dnf install -y
  # tree-sitter-cli is published via npm for yum/dnf.
  sudo dnf install -y nodejs npm
  sudo npm install -g tree-sitter-cli
else
  echo "Unsupported OS"
  exit 1
fi

stow_all

./scripts/bootstrap/shell-config.sh --shell auto

bash ./scripts/bootstrap/lazyvim-requirements.sh
bash ./scripts/curl-installs.sh
# bash ./scripts/install-fonts.sh

bash ./scripts/bootstrap/git-config.sh

echo "Bootstrap complete! Restart your terminal to apply changes."
