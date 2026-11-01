#!/usr/bin/env bash
set -e

# Tools that are not packaged (or not new enough) everywhere.
#   --system  nvim, k9s, lazygit into /usr/local (root, or sudo)
#   --user    starship into ~/.local/bin, uv (never sudo)
#   (none)    both
# The system tools are downloaded release tarballs that are unpacked, never executed as
# installers; the piped install scripts (starship, uv) only ever run as the user.
#
# Each tool is installed when missing, and reinstalled when the copy this script manages
# is not the pinned version, so bumping a version below rolls it out on the next run.
# A copy from somewhere else that comes first on PATH (e.g. Homebrew) is left alone:
# its package manager updates it.

source "$(dirname "$0")/bootstrap/lib.sh"

ARCH=$(uname -m)
OS_TYPE=$(uname)

NVIM_VERSION=0.12.6
K9S_VERSION=0.51.0
LAZYGIT_VERSION=0.66.2
STARSHIP_VERSION=1.27.0

SYSTEM_BIN="/usr/local/bin"
USER_BIN="$HOME/.local/bin"

# Release assets name 64-bit ARM "arm64"; Linux reports it as "aarch64".
release_arch() {
  case "$ARCH" in
    aarch64) echo "arm64" ;;
    *) echo "$ARCH" ;;
  esac
}

# First x.y.z in a command's output, or empty.
version_of() {
  "$@" 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true
}

# Decide whether to (re)install a tool this script puts in $managed_dir.
# Returns 0 to install, 1 to leave it alone. Version arguments are a command that prints
# the installed version, e.g. `needs_install "$SYSTEM_BIN" nvim 0.12.6 --version`.
needs_install() {
  local managed_dir="$1" name="$2" want="$3"
  shift 3
  local found
  found=$(command -v "$name" 2>/dev/null || true)

  if [ -z "$found" ]; then
    return 0
  fi
  if [ "$found" != "$managed_dir/$name" ]; then
    # Installed by something else (a package manager) and first on PATH.
    return 1
  fi

  local have
  have=$(version_of "$managed_dir/$name" "$@")
  if [ "$have" = "$want" ]; then
    return 1
  fi
  echo "Updating $name ${have:-(unknown version)} -> $want"
  return 0
}

install_nvim() {
    needs_install "$SYSTEM_BIN" nvim "$NVIM_VERSION" --version || return 0

    if [[ "$OS_TYPE" == "Darwin" ]]; then
        NVIM_DIR="nvim-macos-$(release_arch)"
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        NVIM_DIR="nvim-linux-$(release_arch)"
    else
        echo "Unsupported OS for Neovim installation"
        return
    fi

    local tmp
    tmp=$(mktemp -d)
    curl -fLo "$tmp/$NVIM_DIR.tar.gz" "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/$NVIM_DIR.tar.gz"
    tar -xzf "$tmp/$NVIM_DIR.tar.gz" -C "$tmp"
    # The old version's runtime files are left in place and overwritten; nvim only reads
    # the runtime that matches its own version.
    as_root cp -rf "$tmp/$NVIM_DIR"/* /usr/local/
    rm -rf "$tmp"
}

install_k9s() {
    # Only worth installing where there is a kubectl to go with it.
    command -v k9s >/dev/null || command -v kubectl >/dev/null || return 0
    needs_install "$SYSTEM_BIN" k9s "$K9S_VERSION" version --short || return 0

    if [[ "$OS_TYPE" == "Darwin" ]]; then
        K9S_OS="Darwin"
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        K9S_OS="Linux"
    else
        echo "Unsupported OS for k9s installation"
        return
    fi

    if [[ "$ARCH" == "x86_64" ]]; then
        K9S_ARCH="amd64"
    elif [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        K9S_ARCH="arm64"
    else
        echo "Unsupported architecture for k9s installation"
        return
    fi

    local tmp tar_ball
    tmp=$(mktemp -d)
    tar_ball="k9s_${K9S_OS}_${K9S_ARCH}.tar.gz"
    curl -fLo "$tmp/$tar_ball" "https://github.com/derailed/k9s/releases/download/v$K9S_VERSION/$tar_ball"
    tar -xzf "$tmp/$tar_ball" -C "$tmp" k9s
    as_root install -m 0755 "$tmp/k9s" "$SYSTEM_BIN/k9s"
    rm -rf "$tmp"
}

install_lazygit() {
    # `lazygit --version` prints "commit=..., version=0.66.2, os=..., git version=...";
    # the first x.y.z is lazygit's own.
    needs_install "$SYSTEM_BIN" lazygit "$LAZYGIT_VERSION" --version || return 0

    if [[ "$OS_TYPE" == "Darwin" ]]; then
        LAZYGIT_OS="darwin"
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        LAZYGIT_OS="linux"
    else
        echo "Unsupported OS for lazygit installation"
        return
    fi

    local tmp url
    tmp=$(mktemp -d)
    url="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_${LAZYGIT_OS}_$(release_arch).tar.gz"
    curl -fL -o "$tmp/lazygit.tar.gz" "$url" || {
        echo "Failed to download lazygit from ${url}; skipping lazygit install." >&2
        rm -rf "$tmp"
        return 0
    }

    # Extract into the temp dir, not the current directory (the dotfiles checkout).
    tar -xzf "$tmp/lazygit.tar.gz" -C "$tmp" lazygit
    as_root install -m 0755 "$tmp/lazygit" "$SYSTEM_BIN/lazygit"
    rm -rf "$tmp"
}

install_starship() {
  if [ "$(command -v starship 2>/dev/null)" = "$SYSTEM_BIN/starship" ]; then
    # Older versions of this script ran the installer as root, which put starship in
    # /usr/local/bin. Install the user's own copy; ~/.local/bin comes first on PATH.
    echo "Installing starship into $USER_BIN (shadows the root-owned $SYSTEM_BIN/starship)"
  else
    needs_install "$USER_BIN" starship "$STARSHIP_VERSION" --version || return 0
  fi
  mkdir -p "$USER_BIN"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$USER_BIN" -v "v$STARSHIP_VERSION"
}

install_uv() {
  if command -v uv >/dev/null; then
    # uv updates itself, but only a copy from its own installer (in ~/.local/bin);
    # a package manager's copy is that package manager's job.
    if [ "$(command -v uv)" = "$USER_BIN/uv" ]; then
      uv self update || echo "uv self update failed; leaving uv as it is." >&2
    fi
    return 0
  fi
  # PATH is handled by config/shells/*/env.*; stop the installer editing rc files
  # (they are symlinks into this repo, so its edits leave the checkout dirty).
  curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
}

install_system_tools() {
    install_nvim
    install_k9s
    install_lazygit
}

install_user_tools() {
    refuse_root_in_foreign_home
    # Non-interactive runs (e.g. from Ansible) don't load the shell config that puts
    # ~/.local/bin on PATH; without it, tools installed there look missing every run.
    case ":$PATH:" in
      *":$USER_BIN:"*) ;;
      *) export PATH="$USER_BIN:$PATH" ;;
    esac
    install_starship
    install_uv
}

case "${1:-}" in
    --system) install_system_tools ;;
    --user) install_user_tools ;;
    "") install_system_tools; install_user_tools ;;
    *) echo "Usage: $0 [--system | --user]" >&2; exit 2 ;;
esac
