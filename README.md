# Cross-Platform Bootstrap (Linux/WSL + Windows Terminal)

Idempotent bootstrap scripts for a modern terminal setup on both Ubuntu/WSL and Windows Terminal. One shared `starship.toml` drives the prompt on both sides.

## What Gets Installed

### Linux / WSL (`setup-linux.sh`)

| Component | Details |
|---|---|
| **Core packages** | `vim` `git` `curl` `tmux` `unzip` `dnsutils` `wget` `build-essential` |
| **Zsh** | Default shell |
| **Starship** | Cross-platform prompt, installed via official installer |
| **Zsh plugins** | `zsh-autosuggestions`, `zsh-syntax-highlighting` in `~/.zsh/` |
| **pyenv** | *Optional* — prompted during setup |
| **Git config** | Prompted for `user.name` and `user.email`; sets sensible defaults |
| **SSH key** | ed25519 key generated if one doesn't exist (prompted for email) |
| **Dotfiles** | `.zshrc`, `.tmux.conf`, `.vimrc` symlinked to `$HOME`; `starship.toml` symlinked to `~/.config/` |

### Windows (`setup-windows.ps1`)

| Component | Details |
|---|---|
| **JetBrains Mono Nerd Font** | Downloaded from NerdFonts releases and installed per-user (no admin required) |
| **Starship** | Installed via `winget` |
| **Starship config** | `dotfiles\starship.toml` copied to `%USERPROFILE%\.config\starship.toml` |
| **PSReadLine 2.2+** | ListView prediction, vim-friendly key bindings |
| **PowerShell profile** | Managed sentinel block added to `$PROFILE` |
| **Git config** | Same defaults as Linux script |
| **SSH key** | ed25519 key generated if one doesn't exist |

## Quick Start

### Linux / WSL

```bash
git clone https://github.com/TJxKing/Bootstrapper ~/bootstrap
cd ~/bootstrap
chmod +x setup-linux.sh
./setup-linux.sh
```

### Windows Terminal (PowerShell 7)

```powershell
git clone https://github.com/TJxKing/Bootstrapper $HOME\bootstrap
cd $HOME\bootstrap
pwsh -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

After either setup completes, **open a new terminal** to activate the new shell/prompt.

## Re-running

Both scripts are idempotent — safe to run again at any time. They skip steps that are already complete and never overwrite user content outside their managed blocks.

## Customizing

### Starship prompt

Edit `dotfiles/starship.toml` and re-run your platform's setup script (Linux re-symlinks; Windows re-copies with backup if changed). Full config reference at [starship.rs/config](https://starship.rs/config/).

### Dotfiles

Edit files in `dotfiles/` and re-run `./setup-linux.sh` — existing symlinks update automatically.

### Adding packages (Linux)

Append to the `CORE_PACKAGES` array in `setup-linux.sh`.

## File Structure

```
.
├── setup-linux.sh        # Linux/WSL bootstrap
├── setup-windows.ps1     # Windows Terminal bootstrap (PS7)
├── README.md
└── dotfiles/
    ├── .zshrc            # Zsh config (Starship + plugins + aliases)
    ├── .tmux.conf        # Tmux sane defaults
    ├── .vimrc            # Vim sane defaults
    └── starship.toml     # Shared Starship prompt config
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

→ The Nerd Font isn't selected in Windows Terminal. Go to Settings → Profile → Appearance → Font face → **JetBrainsMono Nerd Font**.

### Starship not found after install (Linux)

→ The installer puts the binary in `/usr/local/bin`. Open a new shell or run `source ~/.zshrc`.

### Starship not found after winget install (Windows)

→ Open a new `pwsh` session. winget updates `%PATH%` at the machine level but the current session won't see it until restarted.

### pyenv: command not found (after opting in)

→ Open a new terminal. pyenv is loaded via `.zshrc` which only takes effect in a new shell.

### Permission denied on setup-linux.sh

```bash
chmod +x setup-linux.sh
```

### Native Linux font setup (non-WSL, without the Windows script)

```bash
mkdir -p ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip JetBrainsMono.zip "JetBrainsMonoNerdFont*.ttf" -d ~/.local/share/fonts/
rm JetBrainsMono.zip
fc-cache -fv
```
