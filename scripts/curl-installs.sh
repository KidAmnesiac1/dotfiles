#!/usr/bin/env bash
set -e

# Tools that are not packaged (or not new enough) everywhere.
#   --system  nvim, k9s, lazygit into /usr/local (root, or sudo)
#   --user    starship, uv into ~/.local/bin (never sudo)
#   (none)    both
# The system tools are downloaded release tarballs that are unpacked, never executed as
# installers; the piped install scripts (starship, uv) only ever run as the user.

source "$(dirname "$0")/bootstrap/lib.sh"

ARCH=$(uname -m)
OS_TYPE=$(uname)

NVIM_VERSION=v0.12.6
K9S_VERSION=v0.50.18
LAZYGIT_VERSION=0.59.0

USER_BIN="$HOME/.local/bin"

# Release assets name 64-bit ARM "arm64"; Linux reports it as "aarch64".
release_arch() {
  case "$ARCH" in
    aarch64) echo "arm64" ;;
    *) echo "$ARCH" ;;
  esac
}

install_nvim() {
    command -v nvim >/dev/null && return

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
    curl -fLo "$tmp/$NVIM_DIR.tar.gz" "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$NVIM_DIR.tar.gz"
    tar -xzf "$tmp/$NVIM_DIR.tar.gz" -C "$tmp"
    as_root cp -rf "$tmp/$NVIM_DIR"/* /usr/local/
    rm -rf "$tmp"
}

install_k9s() {
    command -v k9s >/dev/null && return
    command -v kubectl >/dev/null || return 0

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
    curl -fLo "$tmp/$tar_ball" "https://github.com/derailed/k9s/releases/download/$K9S_VERSION/$tar_ball"
    tar -xzf "$tmp/$tar_ball" -C "$tmp" k9s
    as_root install -m 0755 "$tmp/k9s" /usr/local/bin/k9s
    rm -rf "$tmp"
}

install_lazygit() {
    command -v lazygit >/dev/null && return

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
    as_root install -m 0755 "$tmp/lazygit" /usr/local/bin/lazygit
    rm -rf "$tmp"
}

install_starship() {
  command -v starship >/dev/null && return
  mkdir -p "$USER_BIN"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$USER_BIN"
}

install_uv() {
  command -v uv >/dev/null && return
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
    install_starship
    install_uv
}

case "${1:-}" in
    --system) install_system_tools ;;
    --user) install_user_tools ;;
    "") install_system_tools; install_user_tools ;;
    *) echo "Usage: $0 [--system | --user]" >&2; exit 2 ;;
esac
