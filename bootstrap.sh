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

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--system | --user]

  (no flag)  Everything: --system, then --user. Run as yourself; only the system
             steps use sudo.
  --system   Packages (Brewfile / apt.txt) and the tools installed into /usr/local
             (nvim, k9s, lazygit). Run as root, or as a user who can sudo. On macOS
             Homebrew must not run as root, so run it as yourself.
  --user     Everything in $HOME: stow, shell config, git config, LazyVim, and
             starship/uv into ~/.local/bin. Never uses sudo.
EOF
}

mode="all"
case "${1:-}" in
  "") ;;
  --system) mode="system" ;;
  --user) mode="user" ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
esac

cd "$(dirname "$0")"
source scripts/bootstrap/lib.sh

# Package names from apt.txt, minus any given as arguments.
package_list() {
  local pkg skip
  while IFS= read -r pkg || [ -n "$pkg" ]; do
    [ -n "$pkg" ] || continue
    for skip in "$@"; do
      [ "$pkg" = "$skip" ] && continue 2
    done
    echo "$pkg"
  done < apt.txt
}

install_packages() {
  local packages
  if [[ "$OSTYPE" == "darwin"* ]]; then
    command -v brew >/dev/null || \
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew bundle
  elif command -v apt >/dev/null; then
    packages=$(package_list)
    # shellcheck disable=SC2086 # one package name per word
    as_root apt install -y $packages
  elif command -v yum >/dev/null || command -v dnf >/dev/null; then
    local pm=yum
    command -v yum >/dev/null || pm=dnf
    if [ "$pm" = yum ]; then
      as_root yum install -y yum-plugin-copr
    else
      as_root dnf install -y dnf-plugins-core
    fi
    # Enable COPR for packages like lazygit.
    as_root "$pm" copr enable -y atim/lazygit
    packages=$(package_list tree-sitter-cli)
    # shellcheck disable=SC2086 # one package name per word
    as_root "$pm" install -y $packages
    # tree-sitter-cli is published via npm for yum/dnf.
    as_root "$pm" install -y nodejs npm
    as_root npm install -g tree-sitter-cli
  else
    echo "Unsupported OS"
    exit 1
  fi
}

run_system() {
  if [[ "$OSTYPE" == "darwin"* ]] && [ "$(id -u)" -eq 0 ]; then
    echo "Homebrew refuses to run as root; run --system as yourself on macOS." >&2
    exit 1
  fi
  echo "Installing system packages and tools..."
  install_packages
  bash ./scripts/curl-installs.sh --system
}

run_user() {
  refuse_root_in_foreign_home
  echo "Setting up dotfiles in $HOME..."
  stow_all
  ./scripts/bootstrap/shell-config.sh --shell auto
  bash ./scripts/curl-installs.sh --user
  bash ./scripts/bootstrap/lazyvim-requirements.sh
  # bash ./scripts/install-fonts.sh
  bash ./scripts/bootstrap/git-config.sh
}

echo "Bootstrapping dotfiles ($mode)..."

case "$mode" in
  all)
    # Check before the system steps so a refused run changes nothing.
    refuse_root_in_foreign_home
    run_system
    run_user
    ;;
  system) run_system ;;
  user) run_user ;;
esac

echo "Bootstrap complete! Restart your terminal to apply changes."
