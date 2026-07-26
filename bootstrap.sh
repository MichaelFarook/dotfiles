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
if (( SKIP_SHELL )); then
    echo "Skipped (--skip-shell)."
elif [ "$(basename "${SHELL:-}")" = "zsh" ]; then
    echo "Default shell is already zsh."
else
    zsh_path="$(command -v zsh)"
    if grep -qx "$zsh_path" /etc/shells 2>/dev/null || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null; then
        chsh -s "$zsh_path" && echo "Default shell set to $zsh_path." \
            || echo "Could not change shell automatically; run: chsh -s $zsh_path"
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
  - Authenticate cloud CLIs as needed: aws configure / az login / gcloud init.
============================================================
EOF
