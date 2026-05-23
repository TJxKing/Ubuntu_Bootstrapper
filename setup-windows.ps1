# =============================================================================
# Windows Terminal Bootstrap
# Idempotent setup: PS7, Git, Nerd Font, Starship, PSReadLine, PowerShell profile, SSH
# Run from Windows PowerShell 5 or PS7:
#   powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
# =============================================================================

# ── PowerShell 7 Bootstrap ────────────────────────────────────────────────────
# PS5-compatible block — must run before Set-StrictMode
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[INFO]  PowerShell 7 not detected. Installing via winget..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] winget not found. Install App Installer from the Microsoft Store, then re-run." -ForegroundColor Red
        exit 1
    }
    winget install --id Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements
    $pwsh = Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe"
    if (Test-Path $pwsh) {
        Write-Host "[INFO]  Relaunching in PowerShell 7..." -ForegroundColor Cyan
        & $pwsh -ExecutionPolicy Bypass -File $PSCommandPath
    } else {
        Write-Host "[INFO]  PS7 installed. Open a new terminal and run: pwsh -ExecutionPolicy Bypass -File .\setup-windows.ps1" -ForegroundColor Yellow
    }
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Helpers ──────────────────────────────────────────────────────────────────
function Write-Info    ($msg) { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok      ($msg) { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    ($msg) { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Section ($msg) { Write-Host "`n━━━ $msg ━━━" -ForegroundColor Magenta }

$ScriptDir = $PSScriptRoot

# ── winget Guard ─────────────────────────────────────────────────────────────
Write-Section "Checking prerequisites"
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget not found. Install App Installer from the Microsoft Store and try again."
    exit 1
}
Write-Ok "winget found"

# ── Git ───────────────────────────────────────────────────────────────────────
Write-Section "Git"
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok "Git already installed ($(git --version))"
} else {
    Write-Info "Installing Git via winget..."
    winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Ok "Git installed ($(git --version))"
    } else {
        Write-Warn "Git installed but not yet in PATH — git commands will work after you restart your terminal."
    }
}

# ── Nerd Font Install ────────────────────────────────────────────────────────
Write-Section "JetBrains Mono Nerd Font"

$FontDest   = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$RegPath    = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
$MarkerFont = Join-Path $FontDest "JetBrainsMonoNerdFont-Regular.ttf"

if (Test-Path $MarkerFont) {
    Write-Ok "JetBrains Mono Nerd Font already installed"
} else {
    $FontZipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    $TempZip    = Join-Path $env:TEMP "JetBrainsMono.zip"
    $TempDir    = Join-Path $env:TEMP "JetBrainsMonoFonts"

    Write-Info "Downloading JetBrainsMono Nerd Font from NerdFonts releases..."
    Invoke-WebRequest -Uri $FontZipUrl -OutFile $TempZip -UseBasicParsing

    Write-Info "Extracting..."
    if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
    Expand-Archive -Path $TempZip -DestinationPath $TempDir -Force
    Remove-Item $TempZip -Force

    $ttfFiles = Get-ChildItem -Path $TempDir -Filter "JetBrainsMonoNerdFont*.ttf" -Recurse
    Write-Info "Installing $($ttfFiles.Count) font files (per-user, no admin required)..."
    New-Item -ItemType Directory -Force -Path $FontDest | Out-Null

    foreach ($ttf in $ttfFiles) {
        $destFile = Join-Path $FontDest $ttf.Name
        Copy-Item -Path $ttf.FullName -Destination $destFile -Force

        # Register in per-user font registry so apps see it without admin
        $displayName = [System.IO.Path]::GetFileNameWithoutExtension($ttf.Name) + " (TrueType)"
        Set-ItemProperty -Path $RegPath -Name $displayName -Value $destFile -Type String -Force
    }

    Remove-Item $TempDir -Recurse -Force
    Write-Ok "JetBrains Mono Nerd Font installed"
}

# ── Starship ─────────────────────────────────────────────────────────────────
Write-Section "Starship"

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Ok "Starship already installed ($(starship --version | Select-Object -First 1))"
} else {
    Write-Info "Installing Starship via winget..."
    winget install --id Starship.Starship --silent --accept-package-agreements --accept-source-agreements
    # Refresh PATH in current session so starship is callable for the rest of the script
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Ok "Starship installed"
}

# ── Starship Config ───────────────────────────────────────────────────────────
Write-Section "Starship config"

$StarshipSrc  = Join-Path $ScriptDir "dotfiles\starship.toml"
$StarshipDest = Join-Path $env:USERPROFILE ".config\starship.toml"

if (-not (Test-Path $StarshipSrc)) {
    Write-Error "starship.toml not found at $StarshipSrc"
    exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path $StarshipDest) | Out-Null

$needsCopy = $true
if (Test-Path $StarshipDest) {
    $srcHash  = (Get-FileHash $StarshipSrc  -Algorithm SHA256).Hash
    $destHash = (Get-FileHash $StarshipDest -Algorithm SHA256).Hash
    if ($srcHash -eq $destHash) {
        Write-Ok "starship.toml already up to date"
        $needsCopy = $false
    } else {
        $backup = "$StarshipDest.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Info "Backing up existing starship.toml → $backup"
        Move-Item $StarshipDest $backup
    }
}

if ($needsCopy) {
    Copy-Item $StarshipSrc $StarshipDest
    Write-Ok "starship.toml copied to $StarshipDest"
}

# ── PSReadLine ───────────────────────────────────────────────────────────────
Write-Section "PSReadLine"

$rlVersion = (Get-Module PSReadLine -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
if ($rlVersion -ge [version]"2.2") {
    Write-Ok "PSReadLine $rlVersion already installed"
} else {
    Write-Info "Installing PSReadLine 2.2+..."
    Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
    Write-Ok "PSReadLine installed"
}

# ── PowerShell Profile ───────────────────────────────────────────────────────
Write-Section "PowerShell profile"

$ProfileDir = Split-Path $PROFILE
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Force -Path $PROFILE | Out-Null
}

$block = @'
# >>> bootstrap >>>
Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Invoke-Expression (& starship init powershell)
# <<< bootstrap <<<
'@

$profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if ($null -eq $profileContent) { $profileContent = "" }

if ($profileContent -match '# >>> bootstrap >>>') {
    # Idempotent replace: swap out the existing sentinel block
    $updated = $profileContent -replace '(?s)# >>> bootstrap >>>.*?# <<< bootstrap <<<', $block.Trim()
    Set-Content $PROFILE $updated -NoNewline
    Write-Ok "Profile bootstrap block updated (idempotent)"
} else {
    Add-Content $PROFILE "`n$block"
    Write-Ok "Profile bootstrap block added"
}

# ── Git Configuration ────────────────────────────────────────────────────────
Write-Section "Git configuration"

$currentName = git config --global user.name 2>$null
if ($currentName) {
    Write-Ok "Git user.name already set: $currentName"
} else {
    $gitName = Read-Host "[?]   Git user.name"
    if ($gitName) {
        git config --global user.name $gitName
        Write-Ok "Git user.name set to: $gitName"
    } else {
        Write-Warn "Skipped — no name entered"
    }
}

$currentEmail = git config --global user.email 2>$null
if ($currentEmail) {
    Write-Ok "Git user.email already set: $currentEmail"
} else {
    $gitEmail = Read-Host "[?]   Git user.email"
    if ($gitEmail) {
        git config --global user.email $gitEmail
        Write-Ok "Git user.email set to: $gitEmail"
    } else {
        Write-Warn "Skipped — no email entered"
    }
}

git config --global init.defaultBranch main
git config --global core.editor vim
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.lg "log --oneline --graph --decorate --all"
Write-Ok "Git config applied"

# ── SSH Key ───────────────────────────────────────────────────────────────────
Write-Section "SSH key"

$SshKey = Join-Path $env:USERPROFILE ".ssh\id_ed25519"
if (Test-Path $SshKey) {
    Write-Ok "SSH key already exists: $SshKey"
} else {
    $sshEmail = Read-Host "[?]   Email for SSH key (blank to skip)"
    if ($sshEmail) {
        $sshDir = Split-Path $SshKey
        New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
        ssh-keygen -t ed25519 -C $sshEmail -f $SshKey -N ''
        Write-Ok "SSH key generated: $SshKey"
        Write-Info "Public key:"
        Get-Content "$SshKey.pub"
    } else {
        Write-Warn "Skipped — no email entered"
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Section "Setup Complete"
Write-Host ""
Write-Ok "JetBrains Mono Nerd Font installed"
Write-Ok "Starship prompt installed"
Write-Ok "starship.toml configured"
Write-Ok "PSReadLine configured"
Write-Ok "PowerShell profile updated"
Write-Ok "Git configured"
if (Test-Path $SshKey) { Write-Ok "SSH key configured" }
Write-Host ""
Write-Info "Open a new pwsh terminal to activate Starship and PSReadLine settings."
Write-Info "Set font in Windows Terminal: Settings → Profile → Appearance → Font face → JetBrainsMono Nerd Font"
