#!/bin/bash

# Set required variables
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export DOTFILES="${DOTFILES:-$HOME/dotfiles}"

########
# nvim #
########

mkdir -p "$XDG_CONFIG_HOME/nvim"
mkdir -p "$XDG_CONFIG_HOME/nvim/undo"

ln -sf "$DOTFILES/nvim/init.vim" "$XDG_CONFIG_HOME/nvim/init.vim"

# install neovim plugin manager
[ ! -f "$DOTFILES/nvim/autoload/plug.vim" ] \
    && curl -fLo "$DOTFILES/nvim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

mkdir -p "$XDG_CONFIG_HOME/nvim/autoload"
ln -sf "$DOTFILES/nvim/autoload/plug.vim" "$XDG_CONFIG_HOME/nvim/autoload/plug.vim"

# Install (or update) all the plugins
if command -v nvim &> /dev/null; then
    nvim --noplugin +PlugUpdate +qa
else
    echo "Warning: nvim not found, skipping plugin installation"
fi

#########
# URxvt #
#########

rm -rf "$XDG_CONFIG_HOME/X11"
ln -sf "$DOTFILES/X11" "$XDG_CONFIG_HOME/X11"

#######
# zsh #
#######

mkdir -p "$XDG_CONFIG_HOME/zsh"
ln -sf "$DOTFILES/zsh/.zshenv" "$HOME/.zshenv"
ln -sf "$DOTFILES/zsh/.zshrc" "$XDG_CONFIG_HOME/zsh/.zshrc"
ln -sf "$DOTFILES/zsh/aliases" "$XDG_CONFIG_HOME/zsh/aliases"

rm -rf "$XDG_CONFIG_HOME/zsh/external"
ln -sf "$DOTFILES/zsh/external" "$XDG_CONFIG_HOME/zsh/external"

#############
# Alacritty #
#############

mkdir -p "$XDG_CONFIG_HOME/alacritty"
ln -sf "$DOTFILES/alacritty/alacritty.toml" "$XDG_CONFIG_HOME/alacritty/alacritty.toml"

# Make Alacritty the terminal GNOME actually launches. Two separate mechanisms
# have to agree, which is why Ctrl+Alt+T kept opening GNOME Terminal:
#
#   1. org.gnome.desktop.default-applications.terminal defaults to
#      'x-terminal-emulator', the Debian alternatives symlink. A snap-installed
#      Alacritty is never registered in alternatives, so that symlink resolves
#      to gnome-terminal. Naming alacritty directly bypasses alternatives, and
#      also fixes "Open in Terminal" in Nautilus.
#   2. The Ctrl+Alt+T binding itself comes from the media-keys 'terminal'
#      action. Replacing it with an explicit custom binding is deterministic
#      across GNOME versions, which disagree on how the default terminal is
#      resolved. The built-in action is cleared first so both do not fire.
#
# Requires a session D-Bus, so this is skipped over a plain SSH connection.
if command -v gsettings &> /dev/null && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] \
   && command -v alacritty &> /dev/null; then
    gsettings set org.gnome.desktop.default-applications.terminal exec 'alacritty' 2>/dev/null || true
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e' 2>/dev/null || true

    kb_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/alacritty/"
    kb_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$kb_path"
    current="$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo '@as []')"

    # Append, never overwrite: any custom keybindings already defined must survive.
    case "$current" in
        *"$kb_path"*)      : ;;
        "@as []"|"[]"|"")  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$kb_path']" ;;
        *)                 gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "${current%]}, '$kb_path']" ;;
    esac

    gsettings set "$kb_schema" name 'Alacritty'
    gsettings set "$kb_schema" command 'alacritty'
    gsettings set "$kb_schema" binding '<Primary><Alt>t'

    # Clear the built-in action last, so a failure above leaves a working terminal.
    gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "@as []" 2>/dev/null \
        || echo "Note: could not clear the built-in terminal shortcut; if Ctrl+Alt+T opens two windows, clear it in Settings > Keyboard."

    echo "Ctrl+Alt+T bound to alacritty, and alacritty set as the default terminal."
else
    echo "Skipping GNOME terminal integration (needs gsettings, a session D-Bus, and alacritty)."
fi

########
# tmux #
########

mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "$DOTFILES/tmux/tmux.conf" "$XDG_CONFIG_HOME/tmux/tmux.conf"

# Tmux Plugin Manager (TPM) — required by the @plugin declarations in tmux.conf.
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# Install the tmux plugins non-interactively (safe to skip if tmux is absent).
if command -v tmux &> /dev/null; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || \
        echo "Warning: tmux plugin install did not complete; open tmux and press prefix + I"
fi
