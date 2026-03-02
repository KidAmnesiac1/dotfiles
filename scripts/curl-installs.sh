#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
OS_TYPE=$(uname)

LAZYGIT_VERSION=0.59.0

install_nvim() {
    command -v nvim >/dev/null && return

    if [[ "$OS_TYPE" == "Darwin" ]]; then
        TAR_BALL="nvim-macos-$ARCH.tar.gz"
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        TAR_BALL="nvim-linux-$ARCH.tar.gz"
    else
        echo "Unsupported OS for Neovim installation"
        return
    fi

    curl -Lo /tmp/$TAR_BALL https://github.com/neovim/neovim/releases/download/stable/$TAR_BALL
    tar -xzf /tmp/$TAR_BALL -C /tmp/
    sudo cp -rf /tmp/${TAR_BALL%.tar.gz}/* /usr/local/
    rm -rf /tmp/${TAR_BALL%.tar.gz} /tmp/$TAR_BALL
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
    
    
    TAR_BALL="k9s_${K9S_OS}_${K9S_ARCH}.tar.gz"
    K9S_VERSION=v0.50.18

    curl -Lo /tmp/$TAR_BALL https://github.com/derailed/k9s/releases/download/$K9S_VERSION/$TAR_BALL
    
    tar -xzf /tmp/$TAR_BALL -C /tmp/
    sudo mv /tmp/k9s /usr/local/bin/k9s
    rm -rf /tmp/${TAR_BALL%.tar.gz} /tmp/$TAR_BALL
}

install_starship() {
  command -v starship >/dev/null && return
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y
}

install_uv() {
  command -v uv >/dev/null && return
  curl -LsSf https://astral.sh/uv/install.sh | sh
}

resolve_lazygit_version() {
    if [[ -n "$LAZYGIT_VERSION" ]]; then
        echo "$LAZYGIT_VERSION"
        return 0
    fi

    local latest_url version
    latest_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/jesseduffield/lazygit/releases/latest || true)
    version=$(sed -E -n 's#.*/tag/v([0-9]+\.[0-9]+\.[0-9]+)$#\1#p' <<<"$latest_url")

    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    fi

    echo "Could not determine latest lazygit release; skipping lazygit install." >&2
    return 1
}

install_lazygit() {

    command -v lazygit >/dev/null && return
    
    if [[ "$OS_TYPE" == "Darwin" ]]; then
        LAZYGIT_OS="darwin"
    elif [[ "$OS_TYPE" == "Linux" ]]; then
        LAZYGIT_OS="linux"
    else
        echo "Unsupported OS for k9s installation"
        return
    fi
    
    local lazygit_version
    lazygit_version="$(resolve_lazygit_version)" || return 0

    LAZYGIT_PACKAGE="https://github.com/jesseduffield/lazygit/releases/download/v${lazygit_version}/lazygit_${lazygit_version}_${LAZYGIT_OS}_${ARCH}.tar.gz"
    curl -fL -o /tmp/lazygit.tar.gz "$LAZYGIT_PACKAGE" || {
        echo "Failed to download lazygit from ${LAZYGIT_PACKAGE}; skipping lazygit install." >&2
        return 0
    }

    tar xf /tmp/lazygit.tar.gz lazygit
    sudo install lazygit -D -t /usr/local/bin/
    rm -rf /tmp/lazygit.tar.gz

}

install_nvim
install_starship
install_uv
install_k9s
install_lazygit
