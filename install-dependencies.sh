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

# Alacritty — the config in alacritty/alacritty.toml targets 0.17.x, which is
# newer than the apt/PPA builds, so install the classic snap. Kept here (not in
# install-tools.sh) because the terminal is a dotfiles dependency, not part of
# the optional DevOps toolchain.
if command -v alacritty &> /dev/null; then
    echo "alacritty already installed."
elif command -v snap &> /dev/null; then
    echo "Installing Alacritty from the classic snap..."
    sudo snap install alacritty --classic
    hash -r 2>/dev/null || true
else
    echo "Warning: snapd is unavailable, so Alacritty was not installed."
    echo "Install it manually from https://github.com/alacritty/alacritty/releases"
fi

# Report what actually resolves on PATH, and flag the two failure modes seen in
# practice: a distro package shadowing the snap, and a version below 0.13, which
# predates TOML support and therefore ignores alacritty.toml completely — the
# terminal then looks unconfigured even though install.sh linked the file.
if command -v alacritty &> /dev/null; then
    alacritty_path="$(command -v alacritty)"
    alacritty_ver="$(alacritty --version 2>/dev/null | awk '{print $2}')"
    echo "alacritty resolves to $alacritty_path (version ${alacritty_ver:-unknown})."
    if dpkg -l alacritty 2>/dev/null | grep -q '^ii'; then
        echo "Warning: the apt 'alacritty' package is installed and may shadow the"
        echo "snap on PATH. Remove it with: sudo apt remove alacritty"
    fi
    if [ -n "$alacritty_ver" ] \
       && [ "$(printf '%s\n0.13.0\n' "$alacritty_ver" | sort -V | head -1)" != "0.13.0" ]; then
        echo "Warning: version $alacritty_ver predates TOML support, which arrived in"
        echo "0.13, so alacritty/alacritty.toml is ignored entirely. Replace this build:"
        echo "  sudo snap install alacritty --classic   # then remove the older one"
    fi
fi

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
