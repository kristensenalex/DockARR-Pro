# backup-arr-stack.ps1 - ARR Stack Full Backup Script
# Version: 4.0
# Description: Complete backup of entire ARR stack including configs, volumes and data

param(
    [string]$BackupPath = ".\backups",
    [switch]$IncludeMedia = $false,
    [switch]$CompressOnly = $false,
    [int]$RetentionDays = 30,
    [switch]$Encrypt = $false,
    [SecureString]$Password,
    [switch]$UploadToCloud = $false,
    [string]$CloudRemote = "gdrive:backups/arr-stack",
    [string]$SevenZipPath = "C:\Program Files\7-Zip\7z.exe"
)

# Colors and formatting
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   ARR STACK FULL BACKUP SYSTEM V4" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Variables
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$TempBackupDir = ".\temp_backup_$Date"
$BackupName = "arr_stack_backup_$Date"
$LogFile = "$BackupPath\backup_$Date.log"

# Function for logging
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

# Create backup folder
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    Write-Log "Created backup folder: $BackupPath"
}

Write-Log "Starting backup process..." "SUCCESS"

# 0. Pre-flight checks
Write-Log "Running pre-flight checks..."

# Check .env file exists
if (!(Test-Path ".env")) {
    Write-Log ".env file not found! Docker Compose requires this file." "ERROR"
    Write-Log "Run: Copy-Item .env.example .env" "ERROR"
    exit 1
}

# Check Docker is running
try {
    docker version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is not started"
    }
} catch {
    Write-Log "Docker is not available!" "ERROR"
    exit 1
}

# Check container health status
Write-Log "Checking container health status..."
$ContainerStatus = docker ps --format "table {{.Names}}\t{{.Status}}"
$UnhealthyContainers = $ContainerStatus | Select-String -Pattern "unhealthy"

if ($UnhealthyContainers) {
    Write-Log "Warning: The following containers are unhealthy:" "WARNING"
    $UnhealthyContainers | ForEach-Object { Write-Log "  $_" "WARNING" }
    $Continue = Read-Host "Continue anyway? [y/N]"
    if ($Continue -ne 'y') { exit 1 }
}

# Check disk space
$DriveInfo = Get-PSDrive -Name (Split-Path -Qualifier $BackupPath)
$FreeSpaceGB = [math]::Round($DriveInfo.Free / 1GB, 2)
Write-Log "Free space on backup drive: $FreeSpaceGB GB"

if ($FreeSpaceGB -lt 10) {
    Write-Log "Warning: Only $FreeSpaceGB GB free space!" "WARNING"
}

# 1. Stop containers for consistent backup (optional)
$StopContainers = Read-Host "Do you want to stop containers for consistent backup? (recommended) [Y/n]"
if ($StopContainers -ne 'n') {
    Write-Log "Stopping containers..."
    docker-compose down

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Error stopping containers" "ERROR"
        $ContinueAnyway = Read-Host "Continue anyway? [y/N]"
        if ($ContinueAnyway -ne 'y') { exit 1 }
    }

    $ContainersStopped = $true
} else {
    Write-Log "Containers still running - backup may be inconsistent" "WARNING"
    $ContainersStopped = $false
}

# 2. Create temp backup folder
New-Item -ItemType Directory -Path $TempBackupDir -Force | Out-Null

# 3. Backup Docker volumes with progress bar
Write-Log "`nBacking up Docker volumes..."
$Volumes = @(
    "qbittorrent_config",
    "prowlarr_config",
    "sonarr_config",
    "radarr_config",
    "lidarr_config",
    "bazarr_config",
    "tdarr_server",
    "tdarr_configs",
    "tdarr_logs",
    "tdarr_cache",
    "portainer_data"
)

$VolumeCount = $Volumes.Count
$VolumeIndex = 0

foreach ($Volume in $Volumes) {
    $VolumeIndex++
    $PercentComplete = ($VolumeIndex / $VolumeCount) * 100

    Write-Progress -Activity "Backing up Docker volumes" `
        -Status "Processing: $Volume" `
        -PercentComplete $PercentComplete `
        -CurrentOperation "$VolumeIndex of $VolumeCount"

    Write-Host "  - Backup $Volume..." -NoNewline

    # Check if volume exists
    $VolumeExists = docker volume ls --format "{{.Name}}" | Select-String -Pattern "^docker_${Volume}$|^${Volume}$"

    if ($VolumeExists) {
        $ActualVolumeName = $VolumeExists.ToString()

        # Backup volume via Docker
        docker run --rm `
            -v ${ActualVolumeName}:/source:ro `
            -v ${PWD}\${TempBackupDir}:/backup `
            alpine `
            tar czf /backup/${Volume}.tar.gz -C /source .

        if ($LASTEXITCODE -eq 0) {
            Write-Host " OK" -ForegroundColor Green
            Write-Log "Volume backup OK: $Volume"
        } else {
            Write-Host " ERROR" -ForegroundColor Red
            Write-Log "Volume backup failed: $Volume" "ERROR"
        }
    } else {
        Write-Host " NOT FOUND" -ForegroundColor Yellow
        Write-Log "Volume not found: $Volume" "WARNING"
    }
}

Write-Progress -Activity "Backing up Docker volumes" -Completed

# 4. Backup configuration files
Write-Log "`nBacking up configuration files..."
$ConfigFiles = @(
    "docker-compose.yml",
    ".env",
    ".env.example",
    "README.md",
    "SETUP_GUIDE.md",
    "backup-arr-stack.ps1"
)

$ConfigBackupDir = "$TempBackupDir\configs"
New-Item -ItemType Directory -Path $ConfigBackupDir -Force | Out-Null

foreach ($File in $ConfigFiles) {
    if (Test-Path $File) {
        Copy-Item $File -Destination $ConfigBackupDir -Force
        Write-Log "Copied: $File"
    }
}

# 5. Backup scripts
if (Test-Path ".\scripts") {
    Write-Log "Backing up scripts..."
    Copy-Item -Path ".\scripts" -Destination "$TempBackupDir\scripts" -Recurse -Force
}

# 6. Backup data folder structure (without media files by default)
Write-Log "`nBacking up data structure..."
$DataBackupDir = "$TempBackupDir\data_structure"
New-Item -ItemType Directory -Path $DataBackupDir -Force | Out-Null

# Save folder structure
Get-ChildItem -Path ".\data" -Recurse -Directory | ForEach-Object {
    $RelativePath = $_.FullName.Replace((Get-Location).Path + "\data\", "")
    New-Item -ItemType Directory -Path "$DataBackupDir\$RelativePath" -Force | Out-Null
}

# Save content overview
Get-ChildItem -Path ".\data" -Recurse |
    Select-Object FullName, Length, LastWriteTime |
    Export-Csv -Path "$TempBackupDir\data_inventory.csv" -NoTypeInformation

# 7. Optional: Backup media files
if ($IncludeMedia) {
    Write-Log "Including media files (this may take a long time)..." "WARNING"

    $MediaSize = (Get-ChildItem -Path ".\data\media" -Recurse -File |
        Measure-Object -Property Length -Sum).Sum / 1GB

    Write-Host "Media size: $([math]::Round($MediaSize, 2)) GB" -ForegroundColor Yellow
    $Confirm = Read-Host "Continue? [y/N]"

    if ($Confirm -eq 'y') {
        robocopy ".\data\media" "$TempBackupDir\media" /E /MT:8 /R:1 /W:1 /NFL /NDL /NP /LOG+:$LogFile
    }
}

# 8. Export Docker images list
Write-Log "`nExporting Docker images list..."
docker images --format "table {{.Repository}}:{{.Tag}}" | Out-File "$TempBackupDir\docker_images.txt"

# 9. System information
Write-Log "Saving system information..."
@"
Backup Information
==================
Date: $(Get-Date)
Hostname: $env:COMPUTERNAME
Docker Version: $(docker version --format '{{.Server.Version}}')
Compose Version: $(docker-compose version --short)
Containers Stopped: $ContainersStopped
Include Media: $IncludeMedia
Encrypted: $Encrypt

Docker Volumes Backed Up:
$($Volumes -join "`n")

Disk Usage:
$(Get-PSDrive -PSProvider FileSystem | Format-Table Name, @{Name="Used GB";Expression={[math]::Round($_.Used/1GB,2)}}, @{Name="Free GB";Expression={[math]::Round($_.Free/1GB,2)}} | Out-String)
"@ | Out-File "$TempBackupDir\backup_info.txt"

# 10. Start containers again if they were stopped
if ($ContainersStopped) {
    Write-Log "`nRestarting containers..."
    docker-compose up -d

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Containers restarted OK" "SUCCESS"
    } else {
        Write-Log "Error restarting containers!" "ERROR"
    }
}

# 11. Compress backup
if (!$CompressOnly) {
    Write-Log "`nCompressing backup..."
    $BackupFile = "$BackupPath\$BackupName.zip"

    # Use Compress-Archive with better compression
    $ProgressPreference = 'SilentlyContinue'
    Compress-Archive -Path "$TempBackupDir\*" -DestinationPath $BackupFile -CompressionLevel Optimal
    $ProgressPreference = 'Continue'

    $BackupSize = [math]::Round((Get-Item $BackupFile).Length / 1MB, 2)
    Write-Log "Backup compressed: $BackupSize MB" "SUCCESS"

    # Remove temp folder
    Remove-Item -Path $TempBackupDir -Recurse -Force
}

# 12. Encryption (optional)
if ($Encrypt) {
    Write-Log "`nEncrypting backup..."

    # Check if 7-Zip is installed
    if (!(Test-Path $SevenZipPath)) {
        # Try alternative locations
        $AlternativePaths = @(
            "C:\Program Files\7-Zip\7z.exe",
            "C:\Program Files (x86)\7-Zip\7z.exe",
            "$env:ProgramFiles\7-Zip\7z.exe",
            "$env:LOCALAPPDATA\7-Zip\7z.exe"
        )

        $Found = $false
        foreach ($Path in $AlternativePaths) {
            if (Test-Path $Path) {
                $SevenZipPath = $Path
                $Found = $true
                Write-Log "7-Zip found at: $Path"
                break
            }
        }

        if (!$Found) {
            Write-Log "7-Zip not found! Download from https://www.7-zip.org/" "ERROR"
            Write-Log "Or use -SevenZipPath parameter" "ERROR"
            Write-Log "Continuing without encryption..." "WARNING"
        }
    }

    if (Test-Path $SevenZipPath) {
        # Convert SecureString to plain text (only for 7-Zip command)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        # Encrypt with 7-Zip
        $EncryptedFile = "$BackupPath\$BackupName.7z"
        & $SevenZipPath a -p"$PlainPassword" -mhe=on -mx=9 $EncryptedFile $BackupFile

        # Clear password from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

        if ($LASTEXITCODE -eq 0) {
            # Delete original zip file
            Remove-Item $BackupFile -Force
            $BackupFile = $EncryptedFile
            Write-Log "Backup encrypted OK" "SUCCESS"
        } else {
            Write-Log "Encryption failed!" "ERROR"
        }
    }
}

# 13. Cloud upload (optional)
if ($UploadToCloud) {
    Write-Log "`nUploading to cloud storage..."

    # Check if rclone is installed
    try {
        rclone version | Out-Null

        # Upload with progress
        Write-Host "Uploading to: $CloudRemote" -ForegroundColor Cyan
        rclone copy $BackupFile $CloudRemote --progress

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Cloud upload OK" "SUCCESS"

            # List files in cloud
            Write-Log "Files in cloud backup:"
            rclone ls $CloudRemote --max-depth 1 | Out-String | Write-Log
        } else {
            Write-Log "Cloud upload failed!" "ERROR"
        }
    } catch {
        Write-Log "Rclone not installed! Download from https://rclone.org/" "ERROR"
    }
}

# 14. Backup retention (delete old backups)
Write-Log "`nHandling backup retention ($RetentionDays days)..."
$OldBackups = Get-ChildItem -Path $BackupPath -Filter "arr_stack_backup_*.*" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

if ($OldBackups) {
    Write-Log "Deleting $($OldBackups.Count) old backups..."
    $OldBackups | ForEach-Object {
        Write-Log "  Deleting: $($_.Name)"
        Remove-Item $_.FullName -Force
        Remove-Item $_.FullName -Force
    }
}

# 15. Verify backup
Write-Log "`nVerifying backup..."
if (Test-Path $BackupFile) {
    $BackupInfo = Get-Item $BackupFile

    # Test archive integrity
    try {
        if ($BackupFile.EndsWith('.zip')) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $TestArchive = [System.IO.Compression.ZipFile]::OpenRead($BackupFile)
            $TestArchive.Dispose()
        } elseif ($BackupFile.EndsWith('.7z')) {
            & $SevenZipPath t $BackupFile | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "7z test failed" }
        }
        Write-Log "Backup verified OK" "SUCCESS"
    } catch {
        Write-Log "Backup verification failed!" "ERROR"
    }
}

# 16. Generate restore script
$RestoreScript = @'
# Auto-generated restore script
param(
    [string]$BackupFile = "BACKUP_FILE_PLACEHOLDER",
    [switch]$SelectiveRestore = $false,
    [string[]]$VolumesToRestore = @()
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   ARR STACK RESTORE SYSTEM" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verify backup file exists
if (!(Test-Path $BackupFile)) {
    Write-Host "Backup file not found: $BackupFile" -ForegroundColor Red
    exit 1
}

# Check free disk space
$DriveInfo = Get-PSDrive -Name (Split-Path -Qualifier ".")
$FreeSpaceGB = [math]::Round($DriveInfo.Free / 1GB, 2)
Write-Host "Free space: $FreeSpaceGB GB" -ForegroundColor Yellow

if ($FreeSpaceGB -lt 20) {
    Write-Host "Warning: Only $FreeSpaceGB GB free space!" -ForegroundColor Yellow
    $Continue = Read-Host "Continue? [y/N]"
    if ($Continue -ne 'y') { exit 1 }
}

# Backup current config
Write-Host "Backing up current config..." -ForegroundColor Yellow
$PreRestoreBackup = ".\pre_restore_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $PreRestoreBackup -Force | Out-Null
Copy-Item "docker-compose.yml", ".env" -Destination $PreRestoreBackup -ErrorAction SilentlyContinue

Write-Host "Restoring from: $BackupFile" -ForegroundColor Yellow
$TempDir = ".\temp_restore_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Handle encrypted files
if ($BackupFile.EndsWith('.7z')) {
    Write-Host "Decrypting backup..." -ForegroundColor Yellow
    $7zipPath = "C:\Program Files\7-Zip\7z.exe"
    $Password = Read-Host "Enter password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    & $7zipPath x -p"$PlainPassword" -o"$TempDir" $BackupFile
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
} else {
    # Extract zip backup
    Expand-Archive -Path $BackupFile -DestinationPath $TempDir -Force
}

# Stop containers
Write-Host "Stopping containers..." -ForegroundColor Yellow
docker-compose down

# Select volumes to restore
if ($SelectiveRestore) {
    $AvailableVolumes = Get-ChildItem "$TempDir\*.tar.gz" | ForEach-Object { $_.BaseName }
    Write-Host "`nAvailable volumes:" -ForegroundColor Cyan
    $AvailableVolumes | ForEach-Object { Write-Host "  - $_" }

    if ($VolumesToRestore.Count -eq 0) {
        $VolumeSelection = Read-Host "`nEnter volumes to restore (comma-separated, or 'all')"
        if ($VolumeSelection -eq 'all') {
            $VolumesToRestore = $AvailableVolumes
        } else {
            $VolumesToRestore = $VolumeSelection -split ',' | ForEach-Object { $_.Trim() }
        }
    }
} else {
    $VolumesToRestore = Get-ChildItem "$TempDir\*.tar.gz" | ForEach-Object { $_.BaseName }
}

# Restore volumes
Write-Host "`nRestoring volumes..." -ForegroundColor Yellow
foreach ($Volume in $VolumesToRestore) {
    Write-Host "  - Restoring: $Volume" -NoNewline

    if (Test-Path "$TempDir\$Volume.tar.gz") {
        docker run --rm `
            -v ${Volume}:/target `
            -v ${PWD}\${TempDir}:/source:ro `
            alpine `
            sh -c "cd /target && tar xzf /source/$Volume.tar.gz"

        if ($LASTEXITCODE -eq 0) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " ERROR" -ForegroundColor Red
        }
    } else {
        Write-Host " NOT FOUND" -ForegroundColor Yellow
    }
}

# Restore config files
$RestoreConfigs = Read-Host "`nRestore config files? [Y/n]"
if ($RestoreConfigs -ne 'n') {
    Copy-Item "$TempDir\configs\*" -Destination . -Force
    Write-Host "Config files restored" -ForegroundColor Green
}

# Start containers
Write-Host "`nStarting containers..." -ForegroundColor Yellow
docker-compose up -d

# Clean up
Remove-Item -Path $TempDir -Recurse -Force

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "        RESTORE COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Pre-restore backup saved in: $PreRestoreBackup" -ForegroundColor Cyan

# Check container status
Start-Sleep -Seconds 10
Write-Host "`nContainer status:" -ForegroundColor Cyan
docker ps --format "table {{.Names}}\t{{.Status}}"
'@

$RestoreScript -replace "BACKUP_FILE_PLACEHOLDER", $BackupFile |
    Out-File "$BackupPath\restore_$Date.ps1" -Encoding UTF8

# 17. Conclusion
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "        BACKUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Backup file: $BackupFile" -ForegroundColor Cyan
Write-Host "Size: $BackupSize MB" -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor Cyan
Write-Host "Restore script: $BackupPath\restore_$Date.ps1" -ForegroundColor Cyan

if ($Encrypt) {
    Write-Host "Encryption: YES (7-Zip AES-256)" -ForegroundColor Yellow
}

if ($UploadToCloud) {
    Write-Host "Cloud backup: $CloudRemote" -ForegroundColor Cyan
}

Write-Host "`nTip: Run restore with:" -ForegroundColor Yellow
Write-Host "  .\backups\restore_$Date.ps1" -ForegroundColor White
Write-Host "`nFor selective restore:" -ForegroundColor Yellow
Write-Host "  .\backups\restore_$Date.ps1 -SelectiveRestore" -ForegroundColor White

Write-Log "`nBackup process complete!" "SUCCESS"

# Show backup content
Write-Host "`nBackup contains:" -ForegroundColor Cyan
if (Test-Path $BackupFile) {
    if ($BackupFile.EndsWith('.zip')) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $Archive = [System.IO.Compression.ZipFile]::OpenRead($BackupFile)
        $Archive.Entries | Group-Object { Split-Path $_.FullName } |
            Select-Object Name, Count | Format-Table
        $Archive.Dispose()
    } elseif ($BackupFile.EndsWith('.7z')) {
        Write-Host "  [Encrypted archive - content protected]" -ForegroundColor Magenta
    }
}