# Dotfiles Setup

This repository contains my personal dotfiles configuration for:
- **Neovim** - Editor configuration
- **Zsh** - Shell configuration with custom prompt
- **Tmux** - Terminal multiplexer
- **Alacritty** - Terminal emulator
- **X11/URxvt** - X11 resources

## Quick Start

On a fresh Ubuntu/Debian machine, three commands are all that is required:

```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
chmod +x bootstrap.sh && ./bootstrap.sh --with-tools
```

`bootstrap.sh` runs the whole setup in order:

1. `install-dependencies.sh` — packages the dotfiles need (zsh, neovim, tmux, git, curl, xclip/xsel, zsh-syntax-highlighting, Alacritty from the classic snap, and fzf from Git).
2. `install-tools.sh` — the DevOps toolchain (Terraform/Terragrunt via `tenv`, the AWS/Azure/GCP CLIs, Docker, kubectl, Helm, eksctl, Argo CD, Go, Node via `nvm`, and more). Included only with `--with-tools`.
3. `install.sh` — symlinks the configs into `~/.config`, installs vim-plug and the Neovim plugins, and installs TPM and the tmux plugins.
4. Sets zsh as the default login shell.

Options:

- `./bootstrap.sh` — dotfiles and their dependencies only (no DevOps toolchain).
- `./bootstrap.sh --with-tools` — everything; recommended for a new work laptop.
- `./bootstrap.sh --skip-shell` — do not change the default shell.
- `./bootstrap.sh --help` — usage.

The scripts are idempotent and safe to re-run. They use `sudo` and may prompt once for your password.

## After Bootstrap

The following steps are not scripted and remain manual:

- **Re-login:** log out and back in (or reboot) so the default-shell change and the `docker` group take effect.
- **Client aliases:** recreate machine-local aliases in `~/.config/zsh/aliases.local` (AWS profiles, cluster contexts, role ARNs). This file is never committed — see Customization.
- **Cloud authentication:** `aws configure`, `az login`, `gcloud init` as needed.
- **Alacritty:** installed by `install-dependencies.sh` from the classic snap (`sudo snap install alacritty --classic`), because the 0.17.x series the config targets is newer than the apt and PPA builds. On a machine without `snapd`, the script prints a warning and you install a release binary manually.

If the tmux or Neovim plugins did not install automatically (for example, if the tools were absent at bootstrap time), install them manually:

- **tmux:** open tmux and press prefix (`Ctrl-s`) then `I` (capital i).
- **Neovim:** open `nvim` and run `:PlugInstall`.

## Configuration Details

### Zsh Configuration
- Custom prompt with git status
- Emacs-style keybindings (Ctrl-R history search, Ctrl-W, Ctrl-E)
- Enhanced tab completion
- Directory stack navigation
- FZF integration (if installed)

### Neovim Configuration
- Vim-plug plugin manager
- Python autocompletion (deoplete + jedi)
- File browser (NERDTree)
- Git integration (fugitive, signify)
- Syntax highlighting and colorscheme

### Tmux Configuration
- Prefix key: `Ctrl-s` (instead of default `Ctrl-b`)
- Vi-style pane navigation
- Dracula theme
- Plugin manager (TPM)
- System clipboard integration

## Troubleshooting

### Zsh not starting correctly
- Ensure `~/.zshenv` exists and is readable
- Check that `$DOTFILES` variable is set correctly
- Verify all external files exist in `zsh/external/`

### Neovim plugins not loading
- Run `:PlugInstall` in neovim
- Check that Python 3 is installed: `python3 --version`
- Verify vim-plug is installed: `ls ~/.config/nvim/autoload/plug.vim`

### Tmux status bar showing errors
- Install `tmux-mem-cpu-load` for memory/CPU display (optional)
- Or it will fallback to basic memory info

### FZF not working
- Install fzf from Git only: `git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all`
- Do not also install the apt `fzf` package: the older apt binary cannot parse the `--min-height 20+` syntax emitted by the newer shell integration, which produces `not a valid integer: 20+` on Ctrl-R
- Shell integration is loaded solely through `~/.fzf.zsh`

## Notes

- All paths use `$DOTFILES` variable (defaults to `~/dotfiles`)
- XDG Base Directory specification is followed where possible
- Configuration is designed to be portable across Ubuntu/Debian systems
- Missing dependencies are handled gracefully (scripts won't fail)

## Customization

To add custom configurations without modifying tracked files:
- **Neovim**: Create `~/.config/nvim/custom.vim` (will be auto-loaded)
- **Zsh secrets**: Create `~/.config/zsh/secrets.zsh` for tokens, keys, and secret environment variables. It is untracked (see `.gitignore`) and is auto-sourced by `.zshrc`.
- **Zsh client aliases**: Create `~/.config/zsh/aliases.local` for client-specific or machine-specific aliases (AWS profiles, cluster contexts, role ARNs). It is untracked (matched by `*.local` in `.gitignore`) and is auto-sourced by `zsh/aliases` when present. `zsh/aliases` also sources `$DOTFILES/zsh/aliases.local`, the legacy location used by older machines, so either path works and both are loaded if both exist. Keep all client infrastructure identifiers here — never in the tracked `zsh/aliases`.
