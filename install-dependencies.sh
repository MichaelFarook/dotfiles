#!/bin/bash
#
# Install the dependencies the dotfiles themselves need, on Ubuntu/Debian.
# Non-interactive and idempotent — safe to re-run. For the broader DevOps
# toolchain (terraform, aws, kubectl, ...) see install-tools.sh.

set -e

echo "Installing dotfiles dependencies..."

# Update package list
sudo apt update

# Required packages. (dircolors is part of coreutils and is intentionally not
# listed here — it is not a standalone apt package.)
sudo apt install -y \
    zsh \
    neovim \
    tmux \
    curl \
    git \
    xclip \
    xsel \
    zsh-syntax-highlighting

# fzf — install from Git only. The apt package ships an old binary (0.29) whose
# shell integration passes `--min-height 20+`, which that binary cannot parse,
# breaking Ctrl-R history search ("not a valid integer: 20+").
if dpkg -l fzf 2>/dev/null | grep -q '^ii'; then
    echo "Warning: the apt 'fzf' package is installed and will shadow the Git"
    echo "install on PATH. Remove it with: sudo apt remove fzf"
fi
if [ -d "$HOME/.fzf" ]; then
    echo "~/.fzf already exists; updating..."
    git -C "$HOME/.fzf" pull --ff-only || true
    "$HOME/.fzf/install" --all
else
    echo "Installing fzf from Git..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all
fi

echo ""
echo "Dependencies installed."
