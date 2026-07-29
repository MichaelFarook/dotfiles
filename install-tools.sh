#!/usr/bin/env bash
#
# install-tools.sh — provision a new Ubuntu/Debian laptop with the CLI tooling
# used on the previous machine (DevOps / cloud-native workflow).
#
# Design:
#   - Idempotent: every tool is skipped if already present.
#   - Correct source per tool: apt, official vendor repo, release binary,
#     nvm (Node), or tenv (Terraform/Terragrunt).
#   - Resilient: a single tool failing does not abort the whole run; failures
#     are collected and reported at the end.
#
# Usage:
#   chmod +x install-tools.sh
#   ./install-tools.sh            # install everything
#   ./install-tools.sh --list     # only print what would be installed
#
# Review before running. It uses sudo and adds vendor apt repositories.

set -uo pipefail

# ----------------------------------------------------------------------------
# Pinnable versions (override via environment, e.g. NODE_VERSION=20 ./install-tools.sh)
# ----------------------------------------------------------------------------
NODE_VERSION="${NODE_VERSION:-22}"          # installed via nvm
JAVA_PKG="${JAVA_PKG:-openjdk-17-jdk}"      # was openjdk-11 on the old laptop
# Go and most binaries resolve their latest stable version at run time.

ARCH="$(dpkg --print-architecture)"          # amd64 / arm64
FAILED=()
LIST_ONLY=0
[[ "${1:-}" == "--list" ]] && LIST_ONLY=1

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
skip() { printf '    \033[0;32m✓ %s already installed\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# run <label> <command...> — execute, record failure but keep going
run() {
    local label="$1"; shift
    if (( LIST_ONLY )); then printf '    would install: %s\n' "$label"; return 0; fi
    if "$@"; then
        printf '    \033[0;32m✓ %s installed\033[0m\n' "$label"
    else
        printf '    \033[0;31m✗ %s FAILED\033[0m\n' "$label"
        FAILED+=("$label")
    fi
}

# latest_gh_release <owner/repo> — print latest release tag (e.g. v1.2.3)
latest_gh_release() {
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

# ----------------------------------------------------------------------------
log "Updating apt and installing base packages"
# ----------------------------------------------------------------------------
if (( ! LIST_ONLY )); then sudo apt update; fi

APT_PKGS=(
    build-essential make cmake gcc            # build toolchain
    git curl wget                             # fetching
    zsh tmux vim neovim                        # shells / editors
    jq tree htop                               # utilities
    ripgrep                                    # rg
    xclip xsel                                 # clipboard (X11)
    python3 python3-pip python3-venv           # Python
    postgresql-client redis-tools              # DB clients (psql, redis-cli)
    ca-certificates gnupg apt-transport-https  # for vendor repos
    "$JAVA_PKG"                                # JDK
)
for p in "${APT_PKGS[@]}"; do
    if dpkg -s "$p" >/dev/null 2>&1; then skip "$p"; else run "$p" sudo apt install -y "$p"; fi
done

# ----------------------------------------------------------------------------
log "fzf (from Git — NOT apt; the apt binary breaks Ctrl-R)"
# ----------------------------------------------------------------------------
if [ -d "$HOME/.fzf" ]; then
    skip "fzf (~/.fzf)"
else
    run "fzf" bash -c 'git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" && "$HOME/.fzf/install" --all'
fi

# ----------------------------------------------------------------------------
log "Node.js via nvm (Node ${NODE_VERSION}) + yarn via corepack"
# ----------------------------------------------------------------------------
if [ -d "$HOME/.config/nvm" ] || [ -d "$HOME/.nvm" ]; then
    skip "nvm"
else
    run "nvm" bash -c 'export NVM_DIR="$HOME/.config/nvm"; mkdir -p "$NVM_DIR"; \
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash'
fi
if (( ! LIST_ONLY )); then
    export NVM_DIR="${NVM_DIR:-$HOME/.config/nvm}"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    if have nvm; then
        run "node ${NODE_VERSION}" bash -c "nvm install ${NODE_VERSION} && corepack enable && corepack prepare yarn@stable --activate"
    fi
fi
# Note: the old laptop's 'yarn 0.32+git' was the Debian 'cmdtest' impostor, not
# real Yarn. corepack (above) provides the genuine Yarn — do not apt-install yarn.

# ----------------------------------------------------------------------------
log "tenv + Terraform + Terragrunt (tenv manages the versions)"
# ----------------------------------------------------------------------------
if have tenv; then
    skip "tenv"
else
    run "tenv" bash -c '
        tag=$(curl -fsSL https://api.github.com/repos/tofuutils/tenv/releases/latest \
              | grep -m1 "\"tag_name\"" | sed -E "s/.*\"([^\"]+)\".*/\1/")
        tmp=$(mktemp -d)
        curl -fsSL -o "$tmp/tenv.deb" \
          "https://github.com/tofuutils/tenv/releases/download/${tag}/tenv_${tag}_'"$ARCH"'.deb"
        sudo dpkg -i "$tmp/tenv.deb"; rm -rf "$tmp"'
fi
if (( ! LIST_ONLY )) && have tenv; then
    run "terraform (via tenv)"  bash -c 'tenv tf install latest  && tenv tf use latest'
    run "terragrunt (via tenv)" bash -c 'tenv tg install latest  && tenv tg use latest'
fi

# ----------------------------------------------------------------------------
log "Docker Engine + Compose v2 plugin (official repo)"
# ----------------------------------------------------------------------------
if have docker; then
    skip "docker"
else
    run "docker" bash -c '
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
          | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch='"$ARCH"' signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
          | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker "$USER"'
    echo "    NOTE: log out/in (or 'newgrp docker') for group membership to take effect."
    echo "    NOTE: use 'docker compose' (v2). The old 'docker-compose' v1 is deprecated."
fi

# ----------------------------------------------------------------------------
log "kubectl (release binary)"
# ----------------------------------------------------------------------------
if have kubectl; then
    skip "kubectl"
else
    run "kubectl" bash -c '
        v=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
        curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${v}/bin/linux/'"$ARCH"'/kubectl"
        sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; rm -f /tmp/kubectl'
fi

# ----------------------------------------------------------------------------
log "Helm (official script)"
# ----------------------------------------------------------------------------
if have helm; then skip "helm"; else
    run "helm" bash -c 'curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'
fi

# ----------------------------------------------------------------------------
log "eksctl (release binary)"
# ----------------------------------------------------------------------------
if have eksctl; then skip "eksctl"; else
    run "eksctl" bash -c '
        curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_'"$ARCH"'.tar.gz" \
          | tar xz -C /tmp
        sudo install -m 0755 /tmp/eksctl /usr/local/bin/eksctl; rm -f /tmp/eksctl'
fi

# ----------------------------------------------------------------------------
log "Argo CD CLI (release binary)"
# ----------------------------------------------------------------------------
if have argocd; then skip "argocd"; else
    run "argocd" bash -c '
        curl -fsSL -o /tmp/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-'"$ARCH"'"
        sudo install -m 0755 /tmp/argocd /usr/local/bin/argocd; rm -f /tmp/argocd'
fi

# ----------------------------------------------------------------------------
log "yq (release binary)"
# ----------------------------------------------------------------------------
if have yq; then skip "yq"; else
    run "yq" bash -c '
        curl -fsSL -o /tmp/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_'"$ARCH"'"
        sudo install -m 0755 /tmp/yq /usr/local/bin/yq; rm -f /tmp/yq'
fi

# ----------------------------------------------------------------------------
log "AWS CLI v2 (official installer)"
# ----------------------------------------------------------------------------
if have aws; then skip "aws-cli"; else
    case "$ARCH" in
        amd64) awszip="awscli-exe-linux-x86_64.zip" ;;
        arm64) awszip="awscli-exe-linux-aarch64.zip" ;;
        *)     awszip="" ;;
    esac
    if [ -n "$awszip" ]; then
        run "aws-cli" bash -c '
            tmp=$(mktemp -d); cd "$tmp"
            curl -fsSL -o awscliv2.zip "https://awscli.amazonaws.com/'"$awszip"'"
            unzip -q awscliv2.zip; sudo ./aws/install; cd /; rm -rf "$tmp"'
    else
        FAILED+=("aws-cli (unsupported arch $ARCH)")
    fi
fi

# ----------------------------------------------------------------------------
log "Azure CLI (official script)"
# ----------------------------------------------------------------------------
if have az; then skip "az"; else
    run "az" bash -c 'curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash'
fi

# ----------------------------------------------------------------------------
log "Google Cloud SDK (official repo)"
# ----------------------------------------------------------------------------
if have gcloud; then skip "gcloud"; else
    run "gcloud" bash -c '
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
          | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
https://packages.cloud.google.com/apt cloud-sdk main" \
          | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
        sudo apt update && sudo apt install -y google-cloud-cli'
fi

# ----------------------------------------------------------------------------
log "Go (latest stable tarball)"
# ----------------------------------------------------------------------------
if have go; then skip "go"; else
    run "go" bash -c '
        v=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
        curl -fsSL -o /tmp/go.tgz "https://go.dev/dl/${v}.linux-'"$ARCH"'.tar.gz"
        sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf /tmp/go.tgz && rm -f /tmp/go.tgz'
    echo "    NOTE: ensure /usr/local/go/bin is on PATH (add to ~/.zshenv if not)."
fi

# ----------------------------------------------------------------------------
log "pre-commit (pip, user install)"
# ----------------------------------------------------------------------------
if have pre-commit; then skip "pre-commit"; else
    run "pre-commit" python3 -m pip install --user pre-commit
fi

# ----------------------------------------------------------------------------
log "OpenVPN 3 (official repo)"
# ----------------------------------------------------------------------------
if have openvpn3; then skip "openvpn3"; else
    run "openvpn3" bash -c '
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://packages.openvpn.net/packages-repo.gpg \
          | sudo tee /etc/apt/keyrings/openvpn.asc >/dev/null
        codename=$(. /etc/os-release && echo $VERSION_CODENAME)
        echo "deb [signed-by=/etc/apt/keyrings/openvpn.asc] \
https://packages.openvpn.net/openvpn3/debian $codename main" \
          | sudo tee /etc/apt/sources.list.d/openvpn3.list >/dev/null
        sudo apt update && sudo apt install -y openvpn3'
fi

# ----------------------------------------------------------------------------
log "Alacritty (installed by install-dependencies.sh)"
# ----------------------------------------------------------------------------
# Alacritty is a dotfiles dependency and is installed from the classic snap by
# install-dependencies.sh. This block only verifies the result.
if have alacritty; then
    skip "alacritty"
elif (( LIST_ONLY )); then
    printf '    would install: alacritty (via install-dependencies.sh)\n'
else
    FAILED+=("alacritty — snapd may be unavailable; see install-dependencies.sh")
    echo "    MISSING — run install-dependencies.sh, or install a release binary"
    echo "    from https://github.com/alacritty/alacritty/releases"
fi

# ----------------------------------------------------------------------------
log "Summary"
# ----------------------------------------------------------------------------
if (( LIST_ONLY )); then
    echo "List-only mode complete."
elif (( ${#FAILED[@]} == 0 )); then
    echo "All requested tools are installed."
else
    echo "The following items failed and need attention:"
    printf '  - %s\n' "${FAILED[@]}"
fi

echo
echo "Post-install reminders:"
echo "  - Run ./install.sh to symlink the dotfiles."
echo "  - Set zsh as default shell: chsh -s \$(which zsh)"
echo "  - Log out/in for the docker group and shell change to apply."
echo "  - Authenticate the cloud CLIs (aws configure / az login / gcloud init)."
