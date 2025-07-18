# =============================================================================
# SUPERINSTALLER.PS1 - Enterprise ARR Stack Auto-Installer
# =============================================================================
# Version: 1.0
# Description: Complete automated installer for enterprise-grade media server
# Features: VPN-protected ARR stack with Mullvad WireGuard, automated backups
# Author: GitHub Copilot & Community
# =============================================================================

param(
    [switch]$SkipPrerequisites = $false,
    [switch]$QuickInstall = $false,
    [string]$InstallPath = "C:\ARR-Stack",
    [switch]$CreateDesktopShortcuts = $true
)

# Require Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "🚨 Administrator privileges required!" -ForegroundColor Red
    Write-Host "Right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

# =============================================================================
# CONFIGURATION & VARIABLES
# =============================================================================
$Script:Config = @{
    Version = "1.0"
    InstallPath = $InstallPath
    DockerComposeUrl = "https://github.com/docker/compose/releases/latest/download/docker-compose-windows-x86_64.exe"
    RequiredPorts = @(5055, 6767, 7878, 8191, 8265, 8266, 8686, 8989, 9091, 9443, 9696, 51413)
    Services = @("Sonarr", "Radarr", "Lidarr", "Bazarr", "Prowlarr", "Transmission", "Overseerr", "Tdarr", "Recyclarr", "Gluetun", "Portainer", "Watchtower", "FlareSolverr")
}

# Color output function
function Write-ColorOutput($Message, $Color = "White") {
    Write-Host $Message -ForegroundColor $Color
}

function Write-Banner {
    Clear-Host
    Write-ColorOutput "╔══════════════════════════════════════════════════════════════════════════════╗" "Cyan"
    Write-ColorOutput "║                    🚀 ENTERPRISE ARR STACK INSTALLER 🚀                    ║" "Cyan"
    Write-ColorOutput "║                                                                              ║" "Cyan"
    Write-ColorOutput "║  🎬 Complete Media Server Stack with VPN Protection                         ║" "White"
    Write-ColorOutput "║  🔒 Mullvad WireGuard VPN Integration                                       ║" "White"
    Write-ColorOutput "║  📦 Automated Backup System                                                 ║" "White"
    Write-ColorOutput "║  🌐 Enterprise-Grade Configuration                                          ║" "White"
    Write-ColorOutput "║                                                                              ║" "Cyan"
    Write-ColorOutput "║  Version: $($Script:Config.Version)                                                              ║" "Gray"
    Write-ColorOutput "╚══════════════════════════════════════════════════════════════════════════════╝" "Cyan"
    Write-Host ""
}

function Write-Step($StepNumber, $Title, $Description = "") {
    Write-Host ""
    Write-ColorOutput "🔹 Step $StepNumber`: $Title" "Yellow"
    if ($Description) {
        Write-ColorOutput "   $Description" "Gray"
    }
    Write-Host ""
}

function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function Test-DockerInstalled {
    try {
        $null = docker --version
        return $true
    } catch {
        return $false
    }
}

function Test-DockerComposeInstalled {
    try {
        $null = docker-compose --version
        return $true
    } catch {
        return $false
    }
}

function Test-PortsAvailable {
    param([array]$Ports)
    
    $blockedPorts = @()
    foreach ($port in $Ports) {
        $connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($connection) {
            $blockedPorts += $port
        }
    }
    return $blockedPorts
}

function Install-Prerequisites {
    Write-Step 1 "Installing Prerequisites" "Docker Desktop, Docker Compose, and utilities"
    
    # Check Docker Desktop
    if (-not (Test-DockerInstalled)) {
        Write-ColorOutput "❌ Docker Desktop not found!" "Red"
        Write-ColorOutput "📥 Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" "Yellow"
        Write-ColorOutput "🔄 After installation, restart this script" "Yellow"
        pause
        exit 1
    } else {
        Write-ColorOutput "✅ Docker Desktop detected" "Green"
    }
    
    # Check Docker service
    $dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    if (-not $dockerService -or $dockerService.Status -ne "Running") {
        Write-ColorOutput "🔄 Starting Docker Desktop..." "Yellow"
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        Write-ColorOutput "⏳ Waiting for Docker to start (this may take a few minutes)..." "Yellow"
        
        do {
            Start-Sleep 10
            try {
                docker version | Out-Null
                $dockerReady = $true
            } catch {
                $dockerReady = $false
                Write-Host "." -NoNewline
            }
        } while (-not $dockerReady)
        
        Write-ColorOutput "`n✅ Docker is ready!" "Green"
    }
    
    # Install Docker Compose if missing
    if (-not (Test-DockerComposeInstalled)) {
        Write-ColorOutput "📥 Installing Docker Compose..." "Yellow"
        $composePath = "$env:ProgramFiles\Docker\Docker\resources\bin\docker-compose.exe"
        if (-not (Test-Path $composePath)) {
            try {
                Invoke-WebRequest -Uri $Script:Config.DockerComposeUrl -OutFile "$env:TEMP\docker-compose.exe"
                Move-Item "$env:TEMP\docker-compose.exe" $composePath -Force
                Write-ColorOutput "✅ Docker Compose installed" "Green"
            } catch {
                Write-ColorOutput "❌ Failed to install Docker Compose" "Red"
                exit 1
            }
        }
    } else {
        Write-ColorOutput "✅ Docker Compose detected" "Green"
    }
}

function New-InstallationDirectory {
    Write-Step 2 "Creating Installation Directory" "Setting up folder structure at $($Script:Config.InstallPath)"
    
    if (Test-Path $Script:Config.InstallPath) {
        $overwrite = Read-Host "📁 Directory exists. Overwrite? [y/N]"
        if ($overwrite -eq 'y') {
            Remove-Item $Script:Config.InstallPath -Recurse -Force
        } else {
            Write-ColorOutput "❌ Installation cancelled" "Red"
            exit 1
        }
    }
    
    # Create main directory
    New-Item -ItemType Directory -Path $Script:Config.InstallPath -Force | Out-Null
    Set-Location $Script:Config.InstallPath
    
    # Create folder structure
    $folders = @(
        "data\media\tv",
        "data\media\movies", 
        "data\media\music",
        "data\torrents\complete",
        "data\torrents\incomplete",
        "data\torrents\watch",
        "data\tdarr_cache",
        "data\recycle\tv",
        "data\recycle\movies",
        "data\recycle\music",
        "backups",
        "scripts\1_Daily_Operations",
        "scripts\2_Manual_Control",
        "scripts\3_Initial_Setup",
        "tdarr\plugins",
        "logs",
        "gluetun_data",
        "gluetun_backup",
        "portainer"
    )
    
    foreach ($folder in $folders) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }
    
    Write-ColorOutput "✅ Directory structure created" "Green"
}

function New-ConfigurationFiles {
    Write-Step 3 "Creating Configuration Files" "Docker Compose, environment, and configuration files"
    
    # Create docker-compose.yml
    $dockerCompose = @'
# -------------------------------------------------------------------
# Enterprise ARR Stack with VPN Protection
# -------------------------------------------------------------------
x-common-properties: &common-properties
  restart: unless-stopped
  environment:
    - PUID=${PUID}
    - PGID=${PGID}
    - TZ=${TZ}
  labels:
    - "com.centurylinklabs.watchtower.enable=true"
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
      labels: "service,environment"

# --- Healthchecks --------------------------------------------------
x-transmission-healthcheck: &transmission-healthcheck
  test: ["CMD", "curl", "-f", "-u", "${TRANSMISSION_USER}:${TRANSMISSION_PASS}", "http://localhost:9091/transmission/web/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s

x-prowlarr-healthcheck: &prowlarr-healthcheck
  test: ["CMD", "curl", "-f", "-H", "X-Api-Key: ${PROWLARR_API_KEY}", "http://localhost:${PROWLARR_PORT}/ping"]
  interval: 2m
  timeout: 10s
  retries: 3

x-sonarr-healthcheck: &sonarr-healthcheck
  test: ["CMD", "curl", "-f", "-H", "X-Api-Key: ${SONARR_API_KEY}", "http://localhost:${SONARR_PORT}/api/v3/system/status"]
  interval: 2m
  timeout: 10s
  retries: 3

x-radarr-healthcheck: &radarr-healthcheck
  test: ["CMD", "curl", "-f", "-H", "X-Api-Key: ${RADARR_API_KEY}", "http://localhost:${RADARR_PORT}/api/v3/system/status"]
  interval: 2m
  timeout: 10s
  retries: 3

x-lidarr-healthcheck: &lidarr-healthcheck
  test: ["CMD", "curl", "-f", "-H", "X-Api-Key: ${LIDARR_API_KEY}", "http://localhost:${LIDARR_PORT}/api/v1/system/status"]
  interval: 2m
  timeout: 10s
  retries: 3

x-bazarr-healthcheck: &bazarr-healthcheck
  test: ["CMD", "curl", "-f", "-H", "X-Api-Key: ${BAZARR_API_KEY}", "http://localhost:${BAZARR_PORT}/api/system/status"]
  interval: 2m
  timeout: 10s
  retries: 3

x-overseerr-healthcheck: &overseerr-healthcheck
  test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:${OVERSEERR_PORT}/api/v1/status"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s

x-recyclarr-healthcheck: &recyclarr-healthcheck
  test: ["CMD", "test", "-f", "/config/recyclarr.yml"]
  interval: 5m
  timeout: 10s
  retries: 2

services:
  # -----------------------------------------------------------------
  # VPN CONTAINER - MULLVAD WIREGUARD (gluetun)
  # -----------------------------------------------------------------
  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    networks:
      - arr-network
    ports:
      - ${TRANSMISSION_PORT}:9091
      - 51413:51413
      - 51413:51413/udp
      - ${PROWLARR_PORT}:${PROWLARR_PORT}
      - ${SONARR_PORT}:${SONARR_PORT}
      - ${RADARR_PORT}:${RADARR_PORT}
      - ${LIDARR_PORT}:${LIDARR_PORT}
      - ${BAZARR_PORT}:${BAZARR_PORT}
      - ${FLARESOLVERR_PORT}:${FLARESOLVERR_PORT}
    environment:
      - VPN_SERVICE_PROVIDER=mullvad
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=${MULLVAD_PRIVATE_KEY}
      - WIREGUARD_ADDRESSES=${MULLVAD_ADDRESSES}
      - TZ=${TZ}
      - DOT=on
      - DNS_ADDRESS=10.64.0.1
      - DNS_KEEP_NAMESERVER=off
      - BLOCK_MALICIOUS=on
      - BLOCK_ADS=off
    volumes:
      - gluetun_data:/gluetun
      - ./gluetun_backup:/backup:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "/gluetun-entrypoint", "healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3

  transmission:
    <<: *common-properties
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - USER=${TRANSMISSION_USER}
      - PASS=${TRANSMISSION_PASS}
      - PEERPORT=51413
    volumes:
      - transmission_config:/config
      - ${DATA_PATH}/torrents:/downloads
      - ${DATA_PATH}/torrents/watch:/watch
    healthcheck: *transmission-healthcheck
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  prowlarr:
    <<: *common-properties
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    volumes:
      - prowlarr_config:/config
    healthcheck: *prowlarr-healthcheck
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  sonarr:
    <<: *common-properties
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - SONARR__RECYCLBIN=${SONARR_RECYCLE_BIN}
    volumes:
      - sonarr_config:/config
      - ${DATA_PATH}:/data
    healthcheck: *sonarr-healthcheck
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G

  radarr:
    <<: *common-properties
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - RADARR__RECYCLBIN=${RADARR_RECYCLE_BIN}
    volumes:
      - radarr_config:/config
      - ${DATA_PATH}:/data
    healthcheck: *radarr-healthcheck
    deploy:
      resources:
        limits:
          memory: 2G
        reservations:
          memory: 1G

  lidarr:
    <<: *common-properties
    image: lscr.io/linuxserver/lidarr:latest
    container_name: lidarr
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - LIDARR__RECYCLBIN=${LIDARR_RECYCLE_BIN}
    volumes:
      - lidarr_config:/config
      - ${DATA_PATH}:/data
    healthcheck: *lidarr-healthcheck
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  bazarr:
    <<: *common-properties
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    volumes:
      - bazarr_config:/config
      - ${DATA_PATH}:/data
    healthcheck: *bazarr-healthcheck
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  flaresolverr:
    <<: *common-properties
    image: ghcr.io/flaresolverr/flaresolverr:latest
    container_name: flaresolverr
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

  overseerr:
    <<: *common-properties
    image: lscr.io/linuxserver/overseerr:latest
    container_name: overseerr
    networks:
      - arr-network
    ports:
      - ${OVERSEERR_PORT}:5055
    volumes:
      - overseerr_config:/config
    healthcheck: *overseerr-healthcheck
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  tdarr:
    <<: *common-properties
    image: ghcr.io/haveagitgat/tdarr:latest
    container_name: tdarr
    networks:
      - arr-network
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - UMASK_SET=${UMASK}
      - serverIP=0.0.0.0
      - serverPort=${TDARR_SERVER_PORT}
      - webUIPort=${TDARR_WEBUI_PORT}
      - internalNode=true
      - inContainer=true
      - nodeName=InternalNode
    volumes:
      - tdarr_server:/app/server
      - tdarr_configs:/app/configs
      - tdarr_logs:/app/logs
      - ${DATA_PATH}/tdarr_cache:/temp
      - ${DATA_PATH}:/data
      - ${TDARR_PLUGINS_PATH}:/app/server/Tdarr/Plugins/Local
    ports:
      - ${TDARR_WEBUI_PORT}:${TDARR_WEBUI_PORT}
      - ${TDARR_SERVER_PORT}:${TDARR_SERVER_PORT}
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 1G

  recyclarr:
    <<: *common-properties
    image: ghcr.io/recyclarr/recyclarr:latest
    container_name: recyclarr
    network_mode: "service:gluetun"
    depends_on:
      gluetun:
        condition: service_healthy
    volumes:
      - ./recyclarr.yml:/config/recyclarr.yml:ro
      - recyclarr_config:/config
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - CRON_SCHEDULE=@daily
      - SONARR_API_KEY=${SONARR_API_KEY}
      - RADARR_API_KEY=${RADARR_API_KEY}
    healthcheck: *recyclarr-healthcheck
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_MONITOR_ONLY=true
      - WATCHTOWER_NOTIFICATIONS_LEVEL=info
      - TZ=${TZ}
    networks:
      - arr-network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - 9443:9443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - arr-network
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

volumes:
  gluetun_data:
  transmission_config:
  prowlarr_config:
  sonarr_config:
  radarr_config:
  lidarr_config:
  bazarr_config:
  overseerr_config:
  tdarr_server:
  tdarr_configs:
  tdarr_logs:
  recyclarr_config:
  portainer_data:

networks:
  arr-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
'@
    
    $dockerCompose | Out-File "docker-compose.yml" -Encoding UTF8
    
    # Create .env template
    $envTemplate = @'
# =============================================================================
# ENTERPRISE ARR STACK ENVIRONMENT CONFIGURATION
# =============================================================================
# DO NOT SHARE THIS FILE - Contains sensitive information
# Copy this to .env and configure your settings

# =============================================================================
# SYSTEM CONFIGURATION
# =============================================================================
PUID=1000
PGID=1000
TZ=Europe/Copenhagen
UMASK=002

# =============================================================================
# FILE PATHS - Adjust for your system
# =============================================================================
DATA_PATH=./data
TDARR_PLUGINS_PATH=./tdarr/plugins
PORTAINER_LICENSE=./portainer/portainer.lic

# =============================================================================
# MULLVAD VPN CONFIGURATION
# =============================================================================
# Get these from your Mullvad account -> WireGuard configuration
MULLVAD_PRIVATE_KEY=your_private_key_here
MULLVAD_ADDRESSES=10.x.x.x/32

# =============================================================================
# APPLICATION PORTS
# =============================================================================
TRANSMISSION_PORT=9091
PROWLARR_PORT=9696
SONARR_PORT=8989
RADARR_PORT=7878
LIDARR_PORT=8686
BAZARR_PORT=6767
FLARESOLVERR_PORT=8191
OVERSEERR_PORT=5055
TDARR_WEBUI_PORT=8265
TDARR_SERVER_PORT=8266

# =============================================================================
# DOCKER IMAGES - Latest stable versions
# =============================================================================
TRANSMISSION_IMAGE=lscr.io/linuxserver/transmission:latest
PROWLARR_IMAGE=lscr.io/linuxserver/prowlarr:latest
SONARR_IMAGE=lscr.io/linuxserver/sonarr:latest
RADARR_IMAGE=lscr.io/linuxserver/radarr:latest
LIDARR_IMAGE=lscr.io/linuxserver/lidarr:latest
BAZARR_IMAGE=lscr.io/linuxserver/bazarr:latest
FLARESOLVERR_IMAGE=ghcr.io/flaresolverr/flaresolverr:latest
OVERSEERR_IMAGE=lscr.io/linuxserver/overseerr:latest
TDARR_IMAGE=ghcr.io/haveagitgat/tdarr:latest
PORTAINER_IMAGE=portainer/portainer-ce:latest

# =============================================================================
# AUTHENTICATION - CHANGE THESE!
# =============================================================================
TRANSMISSION_USER=admin
TRANSMISSION_PASS=your_secure_password_here

# =============================================================================
# API KEYS - Generated after first startup
# =============================================================================
PROWLARR_API_KEY=your_api_key_here
SONARR_API_KEY=your_api_key_here
RADARR_API_KEY=your_api_key_here
LIDARR_API_KEY=your_api_key_here
BAZARR_API_KEY=your_api_key_here

# =============================================================================
# RECYCLE BIN PATHS
# =============================================================================
SONARR_RECYCLE_BIN=/data/recycle/tv
RADARR_RECYCLE_BIN=/data/recycle/movies
LIDARR_RECYCLE_BIN=/data/recycle/music

# =============================================================================
# TRANSMISSION PERFORMANCE TUNING
# =============================================================================
TRANSMISSION_RATIO_LIMIT=2.0
TRANSMISSION_RATIO_LIMIT_ENABLED=true
TRANSMISSION_IDLE_SEEDING_LIMIT=30
TRANSMISSION_IDLE_SEEDING_LIMIT_ENABLED=true
TRANSMISSION_SPEED_LIMIT_DOWN=0
TRANSMISSION_SPEED_LIMIT_DOWN_ENABLED=false
TRANSMISSION_SPEED_LIMIT_UP=0
TRANSMISSION_SPEED_LIMIT_UP_ENABLED=false
TRANSMISSION_PEER_LIMIT_GLOBAL=240
TRANSMISSION_PEER_LIMIT_PER_TORRENT=60
'@
    
    $envTemplate | Out-File ".env.example" -Encoding UTF8
    
    Write-ColorOutput "✅ Configuration files created" "Green"
}

function New-ScriptFiles {
    Write-Step 4 "Creating Management Scripts" "Backup, restore, and maintenance scripts"
    
    # Daily backup script
    $dailyBackup = @'
# ARR Stack Automatic Backup Script - Enterprise Edition
param(
    [string]$BackupPath = ".\backups",
    [int]$RetentionDays = 7
)

$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = "$BackupPath\backup_$Date.log"
$TempDir = ".\temp_backup_$Date"

function Write-Log {
    param($Message, $Type = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Type] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    
    switch ($Type) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message }
    }
}

# Create backup directory
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
}

Write-Log "Starting enterprise backup process..." "SUCCESS"

# Create temp backup directory
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# Backup volumes
$VolumesToBackup = @(
    "transmission_config",
    "prowlarr_config", 
    "sonarr_config",
    "radarr_config",
    "lidarr_config",
    "bazarr_config",
    "overseerr_config",
    "tdarr_server",
    "tdarr_configs",
    "tdarr_logs",
    "recyclarr_config",
    "portainer_data"
)

$FailedVolumes = @()
foreach ($Volume in $VolumesToBackup) {
    Write-Log "Backing up volume: $Volume"
    
    $VolumeExists = docker volume ls --format "{{.Name}}" | Select-String -Pattern "^${Volume}$"
    
    if ($VolumeExists) {
        docker run --rm -v ${Volume}:/source:ro -v ${PWD}\${TempDir}:/backup alpine tar czf /backup/${Volume}.tar.gz -C /source .
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Volume backup successful: $Volume" "SUCCESS"
        } else {
            Write-Log "Volume backup failed: $Volume" "ERROR"
            $FailedVolumes += $Volume
        }
    } else {
        Write-Log "Volume not found: $Volume" "WARNING"
    }
}

# Backup configuration files
Copy-Item "docker-compose.yml", ".env", "recyclarr.yml" -Destination $TempDir -Force -ErrorAction SilentlyContinue

# Compress everything
$BackupFile = "$BackupPath\arr_backup_$Date.zip"
Write-Log "Compressing backup to: $BackupFile"

try {
    Compress-Archive -Path "$TempDir\*" -DestinationPath $BackupFile -CompressionLevel Optimal -ErrorAction Stop
    $BackupSize = [math]::Round((Get-Item $BackupFile).Length / 1MB, 2)
    Write-Log "Backup completed successfully: $BackupSize MB" "SUCCESS"
    
    Remove-Item -Path $TempDir -Recurse -Force
} catch {
    Write-Log "Compression failed: $_" "ERROR"
}

# Clean old backups
Write-Log "Cleaning old backups (keeping last $RetentionDays days)..."
$OldBackups = Get-ChildItem -Path $BackupPath -Filter "arr_backup_*.zip" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

if ($OldBackups) {
    foreach ($OldBackup in $OldBackups) {
        Remove-Item $OldBackup.FullName -Force
        Write-Log "Deleted old backup: $($OldBackup.Name)"
    }
}

Write-Log "=== Backup Summary ===" "SUCCESS"
Write-Log "Backup file: $BackupFile"
Write-Log "Size: $BackupSize MB"
Write-Log "Failed volumes: $($FailedVolumes.Count)"

if ($FailedVolumes.Count -eq $VolumesToBackup.Count) {
    Write-Log "ALL BACKUPS FAILED! Check Docker status!" "ERROR"
    exit 1
}

Write-Log "=== Backup Completed ===" "SUCCESS"
'@
    
    $dailyBackup | Out-File "scripts\1_Daily_Operations\backup-arr-stack-auto.ps1" -Encoding UTF8
    
    # System status script
    $statusScript = @'
# Enterprise ARR Stack Status Monitor
Write-Host "=== ENTERPRISE ARR STACK STATUS ===" -ForegroundColor Cyan
Write-Host ""

# Container status
Write-Host "🐳 Container Status:" -ForegroundColor Yellow
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Where-Object { $_ -notmatch "NAMES" }

Write-Host ""

# Health checks
Write-Host "🏥 Health Status:" -ForegroundColor Yellow
$containers = docker ps --format "{{.Names}}"
foreach ($container in $containers) {
    $health = docker inspect --format="{{.State.Health.Status}}" $container 2>$null
    if ($health) {
        $color = switch ($health) {
            "healthy" { "Green" }
            "unhealthy" { "Red" }
            default { "Yellow" }
        }
        Write-Host "  $container`: $health" -ForegroundColor $color
    }
}

Write-Host ""

# VPN Status
Write-Host "🔒 VPN Status:" -ForegroundColor Yellow
try {
    $vpnIP = docker exec gluetun sh -c "wget -qO- http://httpbin.org/ip" | ConvertFrom-Json
    Write-Host "  VPN IP: $($vpnIP.origin)" -ForegroundColor Green
} catch {
    Write-Host "  VPN Status: Unable to determine" -ForegroundColor Red
}

Write-Host ""

# Disk usage
Write-Host "💾 Disk Usage:" -ForegroundColor Yellow
$dataSize = (Get-ChildItem -Path ".\data" -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Host "  Data folder: $([math]::Round($dataSize, 2)) GB" -ForegroundColor White

$backupSize = (Get-ChildItem -Path ".\backups" -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "  Backups: $([math]::Round($backupSize, 2)) MB" -ForegroundColor White

Write-Host ""
Write-Host "🌐 Access URLs:" -ForegroundColor Yellow
Write-Host "  Transmission: http://localhost:9091" -ForegroundColor Cyan
Write-Host "  Prowlarr: http://localhost:9696" -ForegroundColor Cyan
Write-Host "  Sonarr: http://localhost:8989" -ForegroundColor Cyan
Write-Host "  Radarr: http://localhost:7878" -ForegroundColor Cyan
Write-Host "  Lidarr: http://localhost:8686" -ForegroundColor Cyan
Write-Host "  Bazarr: http://localhost:6767" -ForegroundColor Cyan
Write-Host "  Overseerr: http://localhost:5055" -ForegroundColor Cyan
Write-Host "  Tdarr: http://localhost:8265" -ForegroundColor Cyan
Write-Host "  Portainer: https://localhost:9443" -ForegroundColor Cyan
'@
    
    $statusScript | Out-File "scripts\2_Manual_Control\status.ps1" -Encoding UTF8
    
    Write-ColorOutput "✅ Management scripts created" "Green"
}

function Set-EnvironmentConfiguration {
    Write-Step 5 "Environment Configuration" "Setting up .env file with your preferences"
    
    if (-not $QuickInstall) {
        Write-Host ""
        Write-ColorOutput "🔧 Let's configure your environment:" "Yellow"
        Write-Host ""
        
        # Get user preferences
        $timezone = Read-Host "Enter your timezone (e.g., Europe/Copenhagen, America/New_York) [Europe/Copenhagen]"
        if (-not $timezone) { $timezone = "Europe/Copenhagen" }
        
        $transmissionUser = Read-Host "Enter Transmission username [admin]"
        if (-not $transmissionUser) { $transmissionUser = "admin" }
        
        $transmissionPass = Read-Host "Enter Transmission password" -AsSecureString
        $transmissionPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($transmissionPass))
        
        Write-Host ""
        Write-ColorOutput "📝 VPN Configuration:" "Yellow"
        Write-Host "You'll need to configure Mullvad VPN settings manually in the .env file."
        Write-Host "Get your WireGuard configuration from: https://mullvad.net/account/#/wireguard-config"
        Write-Host ""
        
        # Create .env file
        $envContent = Get-Content ".env.example" -Raw
        $envContent = $envContent -replace 'TZ=Europe/Copenhagen', "TZ=$timezone"
        $envContent = $envContent -replace 'TRANSMISSION_USER=admin', "TRANSMISSION_USER=$transmissionUser"
        $envContent = $envContent -replace 'TRANSMISSION_PASS=your_secure_password_here', "TRANSMISSION_PASS=$transmissionPassPlain"
        $envContent = $envContent -replace 'DATA_PATH=./data', "DATA_PATH=$($Script:Config.InstallPath)\data"
        
        $envContent | Out-File ".env" -Encoding UTF8
        
        Write-ColorOutput "✅ Environment configured" "Green"
    } else {
        Copy-Item ".env.example" ".env"
        Write-ColorOutput "⚡ Quick install: Using default configuration" "Yellow"
    }
}

function Start-Services {
    Write-Step 6 "Starting Services" "Pulling images and starting the ARR stack"
    
    Write-ColorOutput "📥 Pulling Docker images (this may take several minutes)..." "Yellow"
    docker-compose pull
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to pull images" "Red"
        exit 1
    }
    
    Write-ColorOutput "🚀 Starting services..." "Yellow"
    docker-compose up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ Failed to start services" "Red"
        exit 1
    }
    
    Write-ColorOutput "⏳ Waiting for services to become healthy..." "Yellow"
    Start-Sleep 30
    
    # Check service status
    $containers = docker ps --format "{{.Names}}" | Where-Object { $_ -in $Script:Config.Services.ToLower() }
    $healthy = 0
    $total = $containers.Count
    
    foreach ($container in $containers) {
        $status = docker inspect --format="{{.State.Status}}" $container
        if ($status -eq "running") {
            $healthy++
        }
    }
    
    Write-ColorOutput "✅ Services started: $healthy/$total containers running" "Green"
}

function New-DesktopShortcuts {
    if ($CreateDesktopShortcuts) {
        Write-Step 7 "Creating Desktop Shortcuts" "Quick access to management tools"
        
        $desktop = [Environment]::GetFolderPath("Desktop")
        $shortcuts = @(
            @{ Name = "ARR Stack Status"; Target = "powershell.exe"; Arguments = "-ExecutionPolicy Bypass -File `"$($Script:Config.InstallPath)\scripts\2_Manual_Control\status.ps1`""; Icon = "shell32.dll,21" }
            @{ Name = "ARR Stack Backup"; Target = "powershell.exe"; Arguments = "-ExecutionPolicy Bypass -File `"$($Script:Config.InstallPath)\scripts\1_Daily_Operations\backup-arr-stack-auto.ps1`""; Icon = "shell32.dll,4" }
            @{ Name = "Overseerr"; Target = "http://localhost:5055"; Icon = "shell32.dll,14" }
            @{ Name = "Portainer"; Target = "https://localhost:9443"; Icon = "shell32.dll,18" }
        )
        
        foreach ($shortcut in $shortcuts) {
            $shell = New-Object -ComObject WScript.Shell
            $link = $shell.CreateShortcut("$desktop\$($shortcut.Name).lnk")
            $link.TargetPath = $shortcut.Target
            if ($shortcut.Arguments) { $link.Arguments = $shortcut.Arguments }
            $link.IconLocation = $shortcut.Icon
            $link.Save()
        }
        
        Write-ColorOutput "✅ Desktop shortcuts created" "Green"
    }
}

function Show-CompletionSummary {
    Write-Host ""
    Write-ColorOutput "╔══════════════════════════════════════════════════════════════════════════════╗" "Green"
    Write-ColorOutput "║                    🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉               ║" "Green"
    Write-ColorOutput "╚══════════════════════════════════════════════════════════════════════════════╝" "Green"
    Write-Host ""
    
    Write-ColorOutput "📍 Installation Location: $($Script:Config.InstallPath)" "Cyan"
    Write-Host ""
    
    Write-ColorOutput "🌐 Access Your Services:" "Yellow"
    Write-ColorOutput "  • Overseerr (Requests): http://localhost:5055" "Cyan"
    Write-ColorOutput "  • Transmission (Torrents): http://localhost:9091" "Cyan"
    Write-ColorOutput "  • Sonarr (TV Shows): http://localhost:8989" "Cyan"
    Write-ColorOutput "  • Radarr (Movies): http://localhost:7878" "Cyan"
    Write-ColorOutput "  • Lidarr (Music): http://localhost:8686" "Cyan"
    Write-ColorOutput "  • Bazarr (Subtitles): http://localhost:6767" "Cyan"
    Write-ColorOutput "  • Prowlarr (Indexers): http://localhost:9696" "Cyan"
    Write-ColorOutput "  • Tdarr (Transcoding): http://localhost:8265" "Cyan"
    Write-ColorOutput "  • Portainer (Management): https://localhost:9443" "Cyan"
    Write-Host ""
    
    Write-ColorOutput "⚠️  IMPORTANT NEXT STEPS:" "Red"
    Write-ColorOutput "1. 🔐 Configure Mullvad VPN in .env file" "Yellow"
    Write-ColorOutput "2. 🔑 Set up API keys for each service" "Yellow"
    Write-ColorOutput "3. 🔗 Configure service connections" "Yellow"
    Write-ColorOutput "4. 📱 Access Overseerr to start requesting content" "Yellow"
    Write-Host ""
    
    Write-ColorOutput "📚 Configuration Guide:" "Yellow"
    Write-ColorOutput "  • Edit: $($Script:Config.InstallPath)\.env" "Cyan"
    Write-ColorOutput "  • Logs: $($Script:Config.InstallPath)\logs" "Cyan"
    Write-ColorOutput "  • Backups: $($Script:Config.InstallPath)\backups" "Cyan"
    Write-Host ""
    
    Write-ColorOutput "🛠️  Management Commands:" "Yellow"
    Write-ColorOutput "  • Status Check: .\scripts\2_Manual_Control\status.ps1" "Cyan"
    Write-ColorOutput "  • Backup Now: .\scripts\1_Daily_Operations\backup-arr-stack-auto.ps1" "Cyan"
    Write-ColorOutput "  • Stop All: docker-compose down" "Cyan"
    Write-ColorOutput "  • Start All: docker-compose up -d" "Cyan"
    Write-Host ""
    
    Write-ColorOutput "🎬 Enjoy your Enterprise ARR Stack!" "Green"
}

# =============================================================================
# MAIN INSTALLATION PROCESS
# =============================================================================

try {
    Write-Banner
    
    # Pre-flight checks
    if (-not $SkipPrerequisites) {
        Write-Step 0 "Pre-flight Checks" "Verifying system requirements"
        
        # Check ports
        $blockedPorts = Test-PortsAvailable -Ports $Script:Config.RequiredPorts
        if ($blockedPorts.Count -gt 0) {
            Write-ColorOutput "❌ The following ports are in use: $($blockedPorts -join ', ')" "Red"
            Write-ColorOutput "Please close applications using these ports or choose different ports." "Yellow"
            exit 1
        }
        
        Write-ColorOutput "✅ All required ports are available" "Green"
    }
    
    # Installation steps
    Install-Prerequisites
    New-InstallationDirectory  
    New-ConfigurationFiles
    New-ScriptFiles
    Set-EnvironmentConfiguration
    Start-Services
    New-DesktopShortcuts
    Show-CompletionSummary
    
} catch {
    Write-ColorOutput "❌ Installation failed: $_" "Red"
    Write-ColorOutput "Check the error message above and try again." "Yellow"
    exit 1
}

# =============================================================================
# END OF SUPERINSTALLER
# =============================================================================
