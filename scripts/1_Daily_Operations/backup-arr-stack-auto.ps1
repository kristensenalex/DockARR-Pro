# backup-arr-stack-auto.ps1 - Simplified automatic backup script for ARR stack

param(
    [string]$BackupPath = "D:\docker\backups",  # Absolute path
    [int]$RetentionDays = 7  # Keep only 7 days of backups
)

# Start logging
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogFile = "$BackupPath\backup_$Date.log"

# Create backup folder if it doesn't exist
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
}

function Write-Log {
    param($Message, $Type = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Type] $Message"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
    
    # Output to console as well
    switch ($Type) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARNING" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        default { Write-Host $Message }
    }
}

Write-Log "=== ARR Stack Automatic Backup Started ===" "SUCCESS"

# Check disk space on D: drive
try {
    $Drive = Get-PSDrive -Name "D"
    $FreeSpaceGB = [math]::Round($Drive.Free / 1GB, 2)
    Write-Log "Free space on D: drive: $FreeSpaceGB GB"
    
    if ($FreeSpaceGB -lt 5) {
        Write-Log "WARNING: Low disk space! Only $FreeSpaceGB GB free" "WARNING"
        # Send notification or email here if desired
    }
} catch {
    Write-Log "Could not check disk space: $_" "ERROR"
}

# Define which volumes to backup
$VolumesToBackup = @(
    "gluetun_data",          # VPN config
    "transmission_config",    # Download client
    "prowlarr_config",       # Indexer manager
    "sonarr_config",         # TV shows
    "radarr_config",         # Movies
    "lidarr_config",         # Music
    "bazarr_config",         # Subtitles
    "overseerr_config",      # Request management
    "tdarr_server",          # Transcoding server
    "tdarr_configs"          # Transcoding configs
)

# Backup configs and docker-compose files
$TempDir = "$BackupPath\temp_$Date"
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

# Copy config files
$ConfigFiles = @("docker-compose.yml", ".env", "recyclarr.yml")
foreach ($File in $ConfigFiles) {
    if (Test-Path "D:\docker\$File") {
        Copy-Item "D:\docker\$File" -Destination $TempDir -Force
        Write-Log "Copied config: $File"
    }
}

# Backup Docker volumes
Write-Log "Starting Docker volume backup..."
$FailedVolumes = @()

foreach ($Volume in $VolumesToBackup) {
    Write-Log "Backing up volume: $Volume"
    
    # Find the correct volume name (with or without docker_ prefix)
    $ActualVolume = docker volume ls --format "{{.Name}}" | Where-Object { $_ -eq $Volume -or $_ -eq "docker_$Volume" }
    
    if ($ActualVolume) {
        # Backup volume via Docker
        $BackupFile = "$TempDir\${Volume}.tar.gz"
        $Result = docker run --rm `
            -v "${ActualVolume}:/source:ro" `
            -v "${TempDir}:/backup" `
            alpine tar czf "/backup/${Volume}.tar.gz" -C /source . 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Volume backup OK: $Volume"
        } else {
            Write-Log "Volume backup FAILED: $Volume - $Result" "ERROR"
            $FailedVolumes += $Volume
        }
    } else {
        Write-Log "Volume not found: $Volume" "WARNING"
    }
}

# Compress everything to one file
$BackupFile = "$BackupPath\arr_backup_$Date.zip"
Write-Log "Compressing backup to: $BackupFile"

try {
    Compress-Archive -Path "$TempDir\*" -DestinationPath $BackupFile -CompressionLevel Optimal -ErrorAction Stop
    $BackupSize = [math]::Round((Get-Item $BackupFile).Length / 1MB, 2)
    Write-Log "Backup completed successfully: $BackupSize MB" "SUCCESS"
    
    # Clean up temp folder
    Remove-Item -Path $TempDir -Recurse -Force
} catch {
    Write-Log "Compression failed: $_" "ERROR"
}

# Delete old backups
Write-Log "Cleaning old backups (keeping last $RetentionDays days)..."
$OldBackups = Get-ChildItem -Path $BackupPath -Filter "arr_backup_*.zip" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

if ($OldBackups) {
    foreach ($OldBackup in $OldBackups) {
        Remove-Item $OldBackup.FullName -Force
        Write-Log "Deleted old backup: $($OldBackup.Name)"
    }
}

# Summary
Write-Log "=== Backup Summary ===" "SUCCESS"
Write-Log "Backup file: $BackupFile"
Write-Log "Size: $BackupSize MB"
Write-Log "Failed volumes: $($FailedVolumes.Count)"
if ($FailedVolumes.Count -gt 0) {
    Write-Log "Failed: $($FailedVolumes -join ', ')" "WARNING"
}

# Check if all backups failed
if ($FailedVolumes.Count -eq $VolumesToBackup.Count) {
    Write-Log "ALL BACKUPS FAILED! Check Docker status!" "ERROR"
    exit 1
}

Write-Log "=== Backup Completed ===" "SUCCESS"