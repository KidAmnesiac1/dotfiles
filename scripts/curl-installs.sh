#!/usr/bin/env bash
set -e

ARCH=$(uname -m)
OS_TYPE=$(uname)

LAZYGIT_VERSION=

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
    command -v kubectl >/dev/null || return
    
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
    
    LAZYGIT_PACKAGE=https://github.com/jesseduffield/lazygit/releases/download/v$LAZYGIT_VERSION/lazygit_$LAZYGIT_VERSION_$LAZYGIT_OS_$ARCH.tar.gz
    curl -Lo /tmp/lazygit.tar.gz $LAZYGIT_PACKAGE

    tar xf /tmp/lazygit.tar.gz lazygit
    sudo install lazygit -D -t /usr/local/bin/
    rm -rf /tmp/lazygit.tar.gz

}

install_nvim
install_starship
install_uv
install_k9s
install_lazygit
