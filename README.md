# Ubuntu Bootstrap (WSL & Server)

Idempotent shell script that configures a fresh Ubuntu/Debian environment with a modern terminal setup. Works on both WSL and native Ubuntu servers.

## What Gets Installed

| Component | Details |
|---|---|
| **Core packages** | `vim` `git` `curl` `tmux` `unzip` `dnsutils` `wget` `build-essential` |
| **Zsh** | Default shell |
| **Powerlevel10k** | Standalone (no Oh My Zsh), cloned to `~/.powerlevel10k` |
| **Zsh plugins** | `zsh-autosuggestions`, `zsh-syntax-highlighting` in `~/.zsh/` |
| **pyenv** | *Optional* — prompted during setup. Installs pyenv + pyenv-virtualenv |
| **Git config** | Prompted for `user.name` and `user.email`; sets sensible defaults |
| **SSH key** | ed25519 key generated if one doesn't exist (prompted for email) |
| **Dotfiles** | `.zshrc`, `.p10k.zsh`, `.tmux.conf`, `.vimrc` symlinked to `$HOME` |

## Quick Start

### Option 1: Clone and run

```bash
git clone https://github.com/TJxKing/Ubuntu_Bootstrapper ~/bootstrap
cd ~/bootstrap
chmod +x setup.sh
./setup.sh
```

### Option 2: Run directly from a fresh system

```bash
sudo apt-get install -y git
git clone https://github.com/TJxKing/Ubuntu_Bootstrapper ~/bootstrap
cd ~/bootstrap
chmod +x setup.sh
./setup.sh
```

After setup completes, **open a new terminal** (or run `zsh`) to start using your new shell.

## Re-running

The script is idempotent — safe to run again at any time. It will:
- Skip packages already installed
- Pull latest Powerlevel10k and plugin updates
- Skip SSH key generation if a key already exists
- Skip git config if `user.name` / `user.email` are already set
- Back up existing dotfiles before re-linking

## Customizing

### Powerlevel10k prompt
Run `p10k configure` to launch the interactive configuration wizard. Your choices are saved to `~/.p10k.zsh`.

### Dotfiles
Edit the files in `dotfiles/` and re-run `./setup.sh` — existing symlinks will be updated automatically.

### Adding packages
Add entries to the `CORE_PACKAGES` array in `setup.sh`.

## Font Setup (WSL / Windows Terminal)

Powerlevel10k uses special glyphs that require a Nerd Font. **This font must be installed on Windows**, not inside WSL.

### Install JetBrains Mono Nerd Font

1. Download **JetBrainsMono.zip** from [Nerd Fonts Releases](https://github.com/ryanoasis/nerd-fonts/releases/latest)
2. Extract the zip
3. Select all `.ttf` files → Right-click → **Install for all users**
4. Open **Windows Terminal** → Settings → Profile (Ubuntu) → Appearance → Font face → select **`JetBrainsMono Nerd Font`**
5. Restart Windows Terminal

### Native Linux (non-WSL)

```bash
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip JetBrainsMono.zip -d JetBrainsMono
rm JetBrainsMono.zip
fc-cache -fv
```

Then configure your terminal emulator to use **JetBrainsMono Nerd Font**.

## File Structure

```
.
├── setup.sh              # Main bootstrap script
├── README.md             # This file
└── dotfiles/
    ├── .zshrc            # Zsh config (p10k + plugins + aliases)
    ├── .p10k.zsh         # Powerlevel10k lean theme config
    ├── .tmux.conf        # Tmux sane defaults
    └── .vimrc            # Vim sane defaults
```

## Tmux Cheat Sheet

The config rebinds the prefix to `Ctrl+a` (instead of `Ctrl+b`):

| Action | Keys |
|---|---|
| Split horizontal | `Ctrl+a` then `\|` |
| Split vertical | `Ctrl+a` then `-` |
| Navigate panes | `Ctrl+a` then `h/j/k/l` |
| Resize panes | `Ctrl+a` then `H/J/K/L` |
| Reload config | `Ctrl+a` then `r` |

## Troubleshooting

### Icons/glyphs show as boxes or question marks
→ The Nerd Font isn't installed or isn't selected in your terminal. See [Font Setup](#font-setup-wsl--windows-terminal).

### pyenv: command not found (after opting in)
→ Open a new terminal. pyenv is loaded via `.zshrc` which only takes effect in a new shell.

### Permission denied on setup.sh
```bash
chmod +x setup.sh
```
