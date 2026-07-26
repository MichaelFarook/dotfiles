setopt AUTO_PARAM_SLASH
setopt CASE_GLOB
autoload -U compinit; compinit

# Autocomplete hidden files
_comp_options+=(globdots)
source "$DOTFILES/zsh/external/completion.zsh"

fpath=($ZDOTDIR/external $fpath)

autoload -Uz prompt_purification_setup; prompt_purification_setup

source "$XDG_CONFIG_HOME/zsh/aliases"

# Local secrets (tokens, keys). Untracked file, created per-machine. See secrets.zsh.
if [ -f "$ZDOTDIR/secrets.zsh" ]; then
    source "$ZDOTDIR/secrets.zsh"
fi

# Push the current directory visited on to the stack.
setopt AUTO_PUSHD
# Do not store duplicate directories in the stack.
setopt PUSHD_IGNORE_DUPS
# Do not print the directory stack after using pushd or popd.
setopt PUSHD_SILENT


# Use emacs-style command-line keybindings (Ctrl+R search, Ctrl+W, Ctrl+E, ...).
# This must be explicit: zsh otherwise infers vi mode from EDITOR/VISUAL=nvim.
bindkey -e

# VIM settings
#bindkey -v
#export KEYTIMEOUT=1
#
#if [ -f "$DOTFILES/zsh/external/cursor_mode" ] && [ -s "$DOTFILES/zsh/external/cursor_mode" ]; then
#    autoload -Uz cursor_mode && cursor_mode
#fi
#
#zmodload zsh/complist
#bindkey -M menuselect 'h' vi-backward-char
#bindkey -M menuselect 'k' vi-up-line-or-history
#bindkey -M menuselect 'l' vi-forward-char
#bindkey -M menuselect 'j' vi-down-line-or-history
#
#autoload -Uz edit-command-line
#zle -N edit-command-line
#bindkey -M vicmd v edit-command-line

if [ -f "$DOTFILES/zsh/external/bd.zsh" ]; then
    source "$DOTFILES/zsh/external/bd.zsh"
fi

# Scripts zsh
if [ -f "$DOTFILES/zsh/scripts.sh" ]; then
    source "$DOTFILES/zsh/scripts.sh"
fi


# fzf integration is handled by ~/.fzf.zsh (sourced below), which loads the
# scripts shipped with the ~/.fzf install. Do not also source the system
# (/usr/share/doc/fzf) example scripts here: their versions may diverge and
# fight over the Ctrl+R widget.


# Colors
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Should be the last line
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# ~/.fzf.zsh appends ~/.fzf/bin to PATH, so the old system /usr/bin/fzf still
# shadows it. The ~/.fzf/shell scripts ship with the newer ~/.fzf/bin binary
# and pass options (e.g. `--min-height 20+`) the system fzf cannot parse,
# breaking Ctrl+R. Prepend the install dir so the binary matches its scripts.
if [ -d ~/.fzf/bin ]; then
    export PATH="$HOME/.fzf/bin:${PATH}"
fi

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
