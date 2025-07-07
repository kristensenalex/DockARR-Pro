<#
    ARR Stack SuperInstaller v1.1 (ENGLISH)
    ---------------------------------------
    - Interactive menu: Choose exactly which services to include in your stack.
    - Checks for and offers to install Docker, Compose, 7-Zip, rclone.
    - Fetches compose and setup files from any GitHub repo.
    - Modifies docker-compose.yml according to your choices using robust YAML manipulation.
    - Offers backup before reinstall (if relevant).
    ---------------------------------------
    Requires PowerShell 7+.
    Suggestions, bugfixes, and contributions:
    https://github.com/<YOUR_GITHUB_REPO>
#>

# --- SETTINGS ---
$defaultDockerRoot = "D:\docker"
$defaultRepoURL = "https://github.com/linuxserver/docker-templates" # Set to your repo when you have one!
$composeFileName = "docker-compose.yml"
$envExampleFile = ".env.example"
$envFile = ".env"
$backupScript = "backup-arr-stack.ps1"
$readmeFile = "README.md"
$services = @(
    @{Name="Sonarr";      Compose="sonarr"},
    @{Name="Radarr";      Compose="radarr"},
    @{Name="Lidarr";      Compose="lidarr"},
    @{Name="Bazarr";      Compose="bazarr"},
    @{Name="Prowlarr";    Compose="prowlarr"},
    @{Name="qBittorrent"; Compose="qbittorrent"},
    @{Name="Tdarr";       Compose="tdarr"},
    @{Name="FlareSolverr";Compose="flaresolverr"},
    @{Name="Portainer";   Compose="portainer"},
    @{Name="Watchtower";  Compose="watchtower"},
    @{Name="Plex";        Compose="plex"},
    @{Name="Jellyfin";    Compose="jellyfin"}
)

# --- UTILS ---
function Write-Section($msg) {
    Write-Host "`n==== $msg ====" -ForegroundColor Cyan
}
function Pause-Continue() {
    Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
function Select-Menu($title, $options) {
    Write-Host "`n$title"
    $i = 1
    foreach ($opt in $options) {
        Write-Host " [$i] $opt"
        $i++
    }
    Write-Host " [0] Continue / Done"
    $sel = @()
    while ($true) {
        $input = Read-Host "Enter number(s) (comma-separated, 0 to finish, * for all)"
        if ($input -eq "0") { break }
        if ($input -eq "*") { $sel = $options; break }
        $nums = $input -split "," | ForEach-Object { $_.Trim() }
        foreach ($n in $nums) {
            if ($n -match "^\d+$" -and $n -ge 1 -and $n -le $options.Count) {
                if ($sel -notcontains $options[$n-1]) { $sel += $options[$n-1] }
            }
        }
        Write-Host "Selected: $($sel -join ', ')"
    }
    return $sel
}
function Confirm($msg, [bool]$defaultYes = $true) {
    $yesNo = if ($defaultYes) { "[Y/n]" } else { "[y/N]" }
    $r = Read-Host "$msg $yesNo"
    if ($defaultYes) { return ($r -eq "" -or $r -match "^[Yy]") }
    else { return ($r -match "^[Yy]") }
}
function Test-Prog($prog, $test) {
    & cmd /c "$test" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# --- 1. Welcome & MAIN MENU ---
Clear-Host
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ARR Stack SuperInstaller v1.1" -ForegroundColor Green
Write-Host "============================================"
Write-Host "This wizard helps you install, reset, or migrate your media stack."
Write-Host ""
Write-Host "Choose exactly which services you want – the script will guide you."
Write-Host "Run as Administrator for best results!"
Write-Host ""

# --- 2. Choose services ---
Write-Section "Select which services you want in your ARR stack"
$chosenServices = Select-Menu "Choose services (enter numbers, comma-separated, finish with 0, * for all):" ($services | ForEach-Object { $_.Name })
if ($chosenServices.Count -eq 0) { 
    Write-Host "No services selected. Exiting." -ForegroundColor Red
    exit 1
}

# --- 3. Choose installation path ---
Write-Section "Choose installation path (root for docker data and compose)"
$root = Read-Host "Enter install path or press Enter for default [$defaultDockerRoot]"
if ([string]::IsNullOrWhiteSpace($root)) { $root = $defaultDockerRoot }
if (!(Test-Path $root)) {
    Write-Host "Directory $root does not exist, creating..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $root -Force | Out-Null
}

# --- 4. Repo ---
Write-Section "Where to fetch compose and scripts from?"
$repoUrl = Read-Host "Paste GitHub repo URL or press Enter for default [$defaultRepoURL]"
if ([string]::IsNullOrWhiteSpace($repoUrl)) { $repoUrl = $defaultRepoURL }
Write-Host "Fetching files from: $repoUrl" -ForegroundColor Cyan

# --- 5. Check prerequisites ---
Write-Section "Checking prerequisites"
$missing = @()
if (!(Test-Prog "docker" "docker --version")) { $missing += "Docker Desktop" }
if (!(Test-Prog "docker-compose" "docker compose version")) { $missing += "Docker Compose" }
if (!(Test-Prog "7z" "7z")) { $missing += "7-Zip" }
if (!(Test-Prog "rclone" "rclone version")) { $missing += "rclone" }
if ($missing.Count -gt 0) {
    Write-Host "The following programs are missing: $($missing -join ', ')" -ForegroundColor Yellow
    foreach ($m in $missing) {
        if (Confirm "Do you want to install $m now?" $true) {
            switch ($m) {
                "Docker Desktop" { Start-Process "https://www.docker.com/products/docker-desktop" }
                "7-Zip" { Start-Process "https://www.7-zip.org/download.html" }
                "rclone" { Start-Process "https://rclone.org/downloads/" }
            }
        }
    }
    Write-Host "Install missing programs and run the script again when ready." -ForegroundColor Red
    Pause-Continue; exit 1
} else {
    Write-Host "All prerequisites met." -ForegroundColor Green
}

# --- 6. Download Compose and scripts ---
Write-Section "Downloading compose and scripts"
Set-Location $root
if (!(Test-Path $composeFileName) -or Confirm "$composeFileName not found, download from repo?" $true) {
    $url = "$repoUrl/raw/main/$composeFileName"
    try { Invoke-WebRequest -Uri $url -OutFile $composeFileName -ErrorAction Stop }
    catch { Write-Host "Error downloading $composeFileName! Check repo URL." -ForegroundColor Red; exit 1 }
}
foreach ($file in @($envExampleFile, $backupScript, $readmeFile)) {
    if (!(Test-Path $file) -or Confirm("$file not found, download from repo?", $true)) {
        $url = "$repoUrl/raw/main/$file"
        try { Invoke-WebRequest -Uri $url -OutFile $file -ErrorAction Stop }
        catch { Write-Host "Error downloading $file." -ForegroundColor Yellow }
    }
}

# --- 7. Create necessary folders ---
Write-Section "Creating necessary folders"
$folders = @("data", "tdarr", "tdarr\plugins", "backups", "scripts")
foreach ($f in $folders) {
    $fp = Join-Path $root $f
    if (!(Test-Path $fp)) { New-Item -ItemType Directory -Path $fp -Force | Out-Null }
}

# --- 8. Copy and configure .env ---
if (!(Test-Path $envFile)) {
    Copy-Item $envExampleFile $envFile
    Write-Host ".env copied from .env.example. Remember to update paths, ports, etc.!" -ForegroundColor Yellow
    Pause-Continue
}

# --- 9. Backup/migration if existing setup ---
if (Test-Path (Join-Path $root "backups")) {
    if (Confirm "Do you want to backup your existing setup before installing?" $true) {
        & pwsh ".\backup-arr-stack.ps1"
        Pause-Continue
    }
}

# --- 10. Adapt docker-compose.yml according to choices (YAML approach) ---
Write-Section "Adapting docker-compose.yml based on your selections"

# Ensure YAML module is installed
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Installing required module 'powershell-yaml'..." -ForegroundColor Yellow
    Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
}
Import-Module powershell-yaml

$allPossibleServices = $services | ForEach-Object { $_.Compose }
$servicesToKeep = ($services | Where-Object { $chosenServices -contains $_.Name }).Compose
$servicesToRemove = $allPossibleServices | Where-Object { $servicesToKeep -notcontains $_ }

if ($servicesToRemove.Count -gt 0) {
    Write-Host "Removing the following services from the compose file: $($servicesToRemove -join ', ')" -ForegroundColor Yellow
    $composeObject = Get-Content $composeFileName -Raw | ConvertFrom-Yaml

    foreach ($service in $servicesToRemove) {
        if ($composeObject.services.PSObject.Properties.Name -contains $service) {
            $composeObject.services.PSObject.Properties.Remove($service)
        }
    }

    # Save a backup and write the new file
    Rename-Item $composeFileName -NewName "${composeFileName}.original" -Force
    $composeObject | ConvertTo-Yaml -Depth 10 | Out-File $composeFileName -Encoding utf8
    Write-Host "docker-compose.yml has been updated." -ForegroundColor Green
} else {
    Write-Host "All services selected. No changes to docker-compose.yml."
}

# --- 11. Start: docker compose up ---
Write-Section "Starting your new ARR stack"
if (Confirm "Do you want to start the stack now with docker compose up -d?" $true) {
    & docker compose up -d
    Write-Host "Stack started. Check status with: docker compose ps" -ForegroundColor Green
}

# --- 12. End: Next steps ---
Write-Section "Installation complete!"
Write-Host "Read README.md for usage, backup, restore, updating, etc."
Write-Host "Your stack is ready at: $root"
Write-Host "Don't forget to update .env if you haven't already."
Write-Host ""
Write-Host "Tip: Add more services later by running this script again."
Write-Host ""
Pause-Continue