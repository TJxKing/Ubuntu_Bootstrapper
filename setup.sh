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

# ── Pre-flight Questions ─────────────────────────────────────────────────────
section "Pre-flight Questions"

# a) Python / pyenv
if prompt_yn "Install Python development tools (pyenv)?"; then
    INSTALL_PYENV=true
else
    INSTALL_PYENV=false
fi

# b) SSH Key
if prompt_yn "Set up SSH key?"; then
    SETUP_SSH=true
    read -rp "$(printf "${YELLOW}[?]${NC}   Email for SSH key: ")" SSH_EMAIL
else
    SETUP_SSH=false
    SSH_EMAIL=""
fi

# c) Git Configuration
if prompt_yn "Set up Git configuration?"; then
    SETUP_GIT=true

    # user.name — check if already set
    _CURRENT_GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
    if [[ -n "$_CURRENT_GIT_NAME" ]]; then
        if prompt_yn "Git user.name is already set to '${_CURRENT_GIT_NAME}'. Update it?"; then
            read -rp "$(printf "${YELLOW}[?]${NC}   Git user.name: ")" GIT_NAME
        else
            GIT_NAME=""
        fi
    else
        read -rp "$(printf "${YELLOW}[?]${NC}   Git user.name: ")" GIT_NAME
    fi

    # user.email — check if already set
    _CURRENT_GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
    if [[ -n "$_CURRENT_GIT_EMAIL" ]]; then
        if prompt_yn "Git user.email is already set to '${_CURRENT_GIT_EMAIL}'. Update it?"; then
            read -rp "$(printf "${YELLOW}[?]${NC}   Git user.email: ")" GIT_EMAIL
        else
            GIT_EMAIL=""
        fi
    else
        read -rp "$(printf "${YELLOW}[?]${NC}   Git user.email: ")" GIT_EMAIL
    fi
else
    SETUP_GIT=false
    GIT_NAME=""
    GIT_EMAIL=""
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
PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

if command -v pyenv &>/dev/null || [[ -d "$PYENV_ROOT" ]]; then
    # Load pyenv into PATH if it exists on disk but isn't on PATH yet
    if ! command -v pyenv &>/dev/null && [[ -d "$PYENV_ROOT/bin" ]]; then
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
    fi
    success "pyenv already installed ($(pyenv --version))"
elif [[ "$INSTALL_PYENV" == true ]]; then
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
if [[ "$SETUP_GIT" == true ]]; then
    if [[ -n "$GIT_NAME" ]]; then
        git config --global user.name "$GIT_NAME"
        success "Git user.name set to: $GIT_NAME"
    else
        if [[ -n "$_CURRENT_GIT_NAME" ]]; then
            success "Git user.name unchanged: $_CURRENT_GIT_NAME"
        else
            warn "Git user.name not set"
        fi
    fi

    if [[ -n "$GIT_EMAIL" ]]; then
        git config --global user.email "$GIT_EMAIL"
        success "Git user.email set to: $GIT_EMAIL"
    else
        if [[ -n "$_CURRENT_GIT_EMAIL" ]]; then
            success "Git user.email unchanged: $_CURRENT_GIT_EMAIL"
        else
            warn "Git user.email not set"
        fi
    fi

    # Apply remaining git config
    git config --global init.defaultBranch main
    git config --global core.editor vim
    git config --global alias.st status
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.lg "log --oneline --graph --decorate --all"
    success "Git config applied"
else
    info "Skipping Git configuration"
fi

# ── SSH Key ─────────────────────────────────────────────────────────────────
section "SSH Key"
SSH_KEY="${HOME}/.ssh/id_ed25519"
if [[ -f "$SSH_KEY" ]]; then
    success "SSH key already exists: ${SSH_KEY}"
elif [[ "$SETUP_SSH" == true ]] && [[ -n "$SSH_EMAIL" ]]; then
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY" -N ""
    success "SSH key generated: ${SSH_KEY}"
    info "Public key:"
    cat "${SSH_KEY}.pub"
else
    info "Skipping SSH key generation"
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
