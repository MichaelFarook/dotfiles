# For dotfiles
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# For specific data
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# For cached files
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"


export EDITOR="nvim"
export VISUAL="nvim"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# History filepath
export HISTFILE="$ZDOTDIR/.zhistory"
# Maximum events for internal history
export HISTSIZE=10000
# Maximum events in history life
export SAVEHIST=10000

# Derive the repository location from this file's own path rather than assuming
# ~/dotfiles. ~/.zshenv is a symlink into the clone, so ${(%):-%N} resolved with
# :A gives the real file and :h:h gives the repository root. This keeps a clone
# at any path working; without it, completion.zsh, bd.zsh, scripts.sh, and
# aliases.local all fail to load from a non-default location.
if [ -z "${DOTFILES:-}" ]; then
    _dotfiles_root="${${(%):-%N}:A:h:h}"
    if [ -d "$_dotfiles_root/zsh" ]; then
        export DOTFILES="$_dotfiles_root"
    else
        export DOTFILES="$HOME/dotfiles"
    fi
    unset _dotfiles_root
fi

# PATH additions. Ubuntu normally adds ~/.local/bin from ~/.profile, which zsh
# never reads once ZDOTDIR is set above. Without this, user-level installs are
# invisible: pipx and pre-commit (install-tools.sh), the Claude Code native
# installer, and pip --user all target ~/.local/bin. /usr/local/go/bin is where
# install-tools.sh unpacks the Go tarball.
# typeset -U keeps the array free of duplicates when zsh is re-entered.
typeset -U path
for _p in "$HOME/.local/bin" /usr/local/go/bin; do
    [ -d "$_p" ] && path=("$_p" $path)
done
unset _p
export PATH
