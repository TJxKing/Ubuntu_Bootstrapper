#!/usr/bin/env bash
# =============================================================================
# Ubuntu Bootstrap Script (WSL & Server)
# Idempotent setup: zsh, Powerlevel10k, plugins, pyenv (optional), SSH, git, dotfiles
# =============================================================================
set -euo pipefail

# ── Colors & Helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${SCRIPT_DIR}/dotfiles"
BACKUP_DIR="${HOME}/.dotfiles.bak"

info()    { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
success() { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
section() { printf "\n${BOLD}${CYAN}━━━ %s ━━━${NC}\n" "$1"; }

prompt_yn() {
    local prompt="$1"
    local default="${2:-n}"
    local reply
    if [[ "$default" = "y" ]]; then
        read -rp "$(printf "${YELLOW}[?]${NC}   ${prompt} [Y/n]: ")" reply
        reply="${reply:-y}"
    else
        read -rp "$(printf "${YELLOW}[?]${NC}   ${prompt} [y/N]: ")" reply
        reply="${reply:-n}"
    fi
    [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Sudo Detection ──────────────────────────────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ── Environment Detection ───────────────────────────────────────────────────
section "Environment Detection"
if grep -qi microsoft /proc/version 2>/dev/null; then
    info "Running inside WSL"
    IS_WSL=true
else
    info "Running on native Linux"
    IS_WSL=false
fi

# ── System Update ───────────────────────────────────────────────────────────
section "System Update"
info "Updating package lists..."
$SUDO apt-get update -qq
info "Upgrading installed packages..."
$SUDO apt-get upgrade -y -qq
success "System updated"

# ── Core Packages ───────────────────────────────────────────────────────────
section "Core Packages"
CORE_PACKAGES=(vim git curl tmux unzip dnsutils wget build-essential)
MISSING=()

for pkg in "${CORE_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    info "Installing: ${MISSING[*]}"
    $SUDO apt-get install -y -qq "${MISSING[@]}"
    success "Core packages installed"
else
    success "All core packages already installed"
fi

# ── Zsh ─────────────────────────────────────────────────────────────────────
section "Zsh"
if command -v zsh &>/dev/null; then
    success "zsh already installed ($(zsh --version))"
else
    info "Installing zsh..."
    $SUDO apt-get install -y -qq zsh
    success "zsh installed"
fi

# ── Powerlevel10k (Standalone) ──────────────────────────────────────────────
section "Powerlevel10k"
P10K_DIR="${HOME}/.powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
    success "Powerlevel10k already installed"
    info "Pulling latest..."
    git -C "$P10K_DIR" pull -q 2>/dev/null || warn "Could not update Powerlevel10k (offline?)"
else
    info "Cloning Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    success "Powerlevel10k installed"
fi

# ── Zsh Plugins ─────────────────────────────────────────────────────────────
section "Zsh Plugins"
ZSH_PLUGIN_DIR="${HOME}/.zsh"
mkdir -p "$ZSH_PLUGIN_DIR"

declare -A PLUGINS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
)

for plugin in "${!PLUGINS[@]}"; do
    plugin_path="${ZSH_PLUGIN_DIR}/${plugin}"
    if [[ -d "$plugin_path" ]]; then
        success "${plugin} already installed"
        git -C "$plugin_path" pull -q 2>/dev/null || warn "Could not update ${plugin} (offline?)"
    else
        info "Cloning ${plugin}..."
        git clone --depth=1 "${PLUGINS[$plugin]}" "$plugin_path"
        success "${plugin} installed"
    fi
done

# ── Python / pyenv (Optional) ──────────────────────────────────────────────
section "Python (pyenv)"
if command -v pyenv &>/dev/null; then
    success "pyenv already installed ($(pyenv --version))"
elif prompt_yn "Install Python development tools (pyenv)?"; then
    # pyenv build dependencies
    PYENV_DEPS=(
        libssl-dev libbz2-dev libreadline-dev libsqlite3-dev
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev
        libffi-dev liblzma-dev
    )
    info "Installing pyenv build dependencies..."
    $SUDO apt-get install -y -qq "${PYENV_DEPS[@]}"

    info "Installing pyenv via official installer..."
    curl -fsSL https://pyenv.run | bash

    # Make pyenv available for the rest of this script
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"

    success "pyenv installed ($(pyenv --version))"
else
    info "Skipping pyenv installation"
fi

# ── Git Configuration ───────────────────────────────────────────────────────
section "Git Configuration"
if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
    read -rp "$(printf "${YELLOW}[?]${NC}   Git user.name: ")" GIT_NAME
    if [[ -n "$GIT_NAME" ]]; then
        git config --global user.name "$GIT_NAME"
        success "Git user.name set to: $GIT_NAME"
    else
        warn "Skipped — no name entered"
    fi
else
    success "Git user.name already set: $(git config --global user.name)"
fi

if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
    read -rp "$(printf "${YELLOW}[?]${NC}   Git user.email: ")" GIT_EMAIL
    if [[ -n "$GIT_EMAIL" ]]; then
        git config --global user.email "$GIT_EMAIL"
        success "Git user.email set to: $GIT_EMAIL"
    else
        warn "Skipped — no email entered"
    fi
else
    success "Git user.email already set: $(git config --global user.email)"
fi

# Apply remaining git config from dotfile (won't overwrite name/email set above)
git config --global init.defaultBranch main
git config --global core.editor vim
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.lg "log --oneline --graph --decorate --all"
success "Git config applied"

# ── SSH Key ─────────────────────────────────────────────────────────────────
section "SSH Key"
SSH_KEY="${HOME}/.ssh/id_ed25519"
if [[ -f "$SSH_KEY" ]]; then
    success "SSH key already exists: ${SSH_KEY}"
else
    read -rp "$(printf "${YELLOW}[?]${NC}   Email for SSH key (blank to skip): ")" SSH_EMAIL
    if [[ -n "$SSH_EMAIL" ]]; then
        mkdir -p "${HOME}/.ssh"
        chmod 700 "${HOME}/.ssh"
        ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY" -N ""
        success "SSH key generated: ${SSH_KEY}"
        info "Public key:"
        cat "${SSH_KEY}.pub"
    else
        warn "Skipped — no email entered"
    fi
fi

# ── Symlink Dotfiles ────────────────────────────────────────────────────────
section "Dotfiles"
if [[ ! -d "$DOTFILES_DIR" ]]; then
    warn "Dotfiles directory not found: ${DOTFILES_DIR}"
    warn "Skipping dotfile symlinks"
else
    mkdir -p "$BACKUP_DIR"
    DOTFILES=(.zshrc .p10k.zsh .tmux.conf .vimrc)

    for dotfile in "${DOTFILES[@]}"; do
        src="${DOTFILES_DIR}/${dotfile}"
        dest="${HOME}/${dotfile}"

        if [[ ! -f "$src" ]]; then
            warn "Source not found, skipping: ${src}"
            continue
        fi

        # Already correctly linked
        if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]]; then
            success "${dotfile} already linked"
            continue
        fi

        # Backup existing file
        if [[ -e "$dest" ]] || [[ -L "$dest" ]]; then
            info "Backing up existing ${dotfile} → ${BACKUP_DIR}/"
            mv "$dest" "${BACKUP_DIR}/${dotfile}.$(date +%Y%m%d%H%M%S)"
        fi

        ln -s "$src" "$dest"
        success "${dotfile} → linked"
    done
fi

# ── Default Shell ───────────────────────────────────────────────────────────
section "Default Shell"
ZSH_PATH="$(which zsh)"
CURRENT_SHELL="$(getent passwd "$(whoami)" | cut -d: -f7)"

if [[ "$CURRENT_SHELL" = "$ZSH_PATH" ]]; then
    success "Default shell is already zsh"
else
    info "Changing default shell to zsh..."
    chsh -s "$ZSH_PATH"
    success "Default shell set to zsh"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
section "Setup Complete"
echo ""
printf "${GREEN}${BOLD}  ✓ Core packages installed${NC}\n"
printf "${GREEN}${BOLD}  ✓ Zsh + Powerlevel10k (standalone)${NC}\n"
printf "${GREEN}${BOLD}  ✓ Plugins: autosuggestions, syntax-highlighting${NC}\n"
if command -v pyenv &>/dev/null; then
    printf "${GREEN}${BOLD}  ✓ pyenv installed${NC}\n"
fi
if [[ -f "$SSH_KEY" ]]; then
    printf "${GREEN}${BOLD}  ✓ SSH key configured${NC}\n"
fi
printf "${GREEN}${BOLD}  ✓ Git configured${NC}\n"
printf "${GREEN}${BOLD}  ✓ Dotfiles symlinked${NC}\n"
printf "${GREEN}${BOLD}  ✓ Default shell: zsh${NC}\n"
echo ""

if $IS_WSL; then
    warn "WSL Detected — Install JetBrains Mono Nerd Font on Windows for Powerlevel10k icons"
    info "Download: https://github.com/ryanoasis/nerd-fonts/releases/latest"
    info "Search for 'JetBrainsMono.zip', install the fonts, then set in Windows Terminal settings"
fi

info "Open a new terminal session (or run 'zsh') to start using your new shell"
info "Run 'p10k configure' to customize your Powerlevel10k prompt"
