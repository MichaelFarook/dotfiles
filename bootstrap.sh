#!/usr/bin/env bash
#
# bootstrap.sh — one-command setup for these dotfiles on a fresh Ubuntu/Debian
# machine. Runs the dependency, symlink, and plugin steps in order so that the
# only manual actions required are: clone, chmod, run.
#
# Usage:
#   ./bootstrap.sh                # dotfiles + their dependencies
#   ./bootstrap.sh --with-tools   # also install the full DevOps toolchain
#   ./bootstrap.sh --skip-shell   # do not change the default login shell
#
# It uses sudo (for apt and vendor installs) and may prompt once for your
# password, and once more for the login-shell change unless --skip-shell.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES="$SCRIPT_DIR"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

WITH_TOOLS=0
SKIP_SHELL=0
for arg in "$@"; do
    case "$arg" in
        --with-tools) WITH_TOOLS=1 ;;
        --skip-shell) SKIP_SHELL=1 ;;
        -h|--help)
            awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1;35m########  %s  ########\033[0m\n' "$*"; }

# 1. Dependencies the dotfiles need (zsh, nvim, tmux, fzf, ...)
step "1/4  Installing dotfiles dependencies"
bash "$DOTFILES/install-dependencies.sh"

# 2. Optional: the broader DevOps toolchain
if (( WITH_TOOLS )); then
    step "2/4  Installing DevOps toolchain"
    bash "$DOTFILES/install-tools.sh"
else
    step "2/4  Skipping DevOps toolchain (pass --with-tools to include it)"
fi

# 3. Symlink configs, plugin managers, and plugins (nvim + tmux)
step "3/4  Linking dotfiles and installing plugins"
bash "$DOTFILES/install.sh"

# 4. Make zsh the default login shell
step "4/4  Setting default shell"
# Compare against the login shell recorded in /etc/passwd, not $SHELL. $SHELL
# reports only the shell of the process that invoked this script, so running
# bootstrap from an interactive zsh made this branch claim success while every
# new login — and every tmux pane, since tmux takes its default-shell from the
# same source — still started bash.
if (( SKIP_SHELL )); then
    echo "Skipped (--skip-shell)."
elif ! zsh_path="$(command -v zsh)"; then
    echo "zsh is not installed; cannot set it as the login shell." >&2
else
    passwd_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
    if [ "$passwd_shell" = "$zsh_path" ]; then
        echo "Login shell is already $zsh_path."
    else
        echo "Login shell is ${passwd_shell:-unknown}; changing it to $zsh_path."
        grep -qxF "$zsh_path" /etc/shells 2>/dev/null \
            || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
        if chsh -s "$zsh_path"; then
            echo "Login shell set to $zsh_path. A full logout is required."
        else
            echo "Could not change the shell automatically; run: chsh -s $zsh_path" >&2
        fi
    fi
fi

cat <<'EOF'

============================================================
Bootstrap complete.

Final manual steps:
  - Log out and back in (or reboot) so the shell change and the
    docker group (if --with-tools was used) take effect.
  - Recreate machine-local client aliases in ~/.config/zsh/aliases.local
    (AWS profiles, cluster contexts, role ARNs — never committed).
    zsh/aliases sources that path and $DOTFILES/zsh/aliases.local, so a
    file in either location is picked up.
  - Authenticate cloud CLIs as needed: aws configure / az login / gcloud init.
============================================================
EOF
