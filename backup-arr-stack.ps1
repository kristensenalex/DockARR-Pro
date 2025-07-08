# ARR Stack Full Backup Script
# Version: 4.0
# Beskrivelse: Komplet backup af hele ARR stack inkl. configs, volumes og data

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

# Farver og formattering
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

# Variabler
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$TempBackupDir = ".\temp_backup_$Date"
$BackupName = "arr_stack_backup_$Date"
$LogFile = "$BackupPath\backup_$Date.log"

# Funktion til at logge
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

# Opret backup mappe
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    Write-Log "Oprettet backup mappe: $BackupPath"
}

Write-Log "Starter backup proces..." "SUCCESS"

# 0. Pre-flight checks
Write-Log "Kører pre-flight checks..."

# Tjek .env fil eksisterer
if (!(Test-Path ".env")) {
    Write-Log ".env fil ikke fundet! Docker Compose kræver denne fil." "ERROR"
    Write-Log "Kør: Copy-Item .env.example .env" "ERROR"
    exit 1
}

# Tjek Docker kører
try {
    docker version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker er ikke startet"
    }
} catch {
    Write-Log "Docker er ikke tilgængelig!" "ERROR"
    exit 1
}

# Tjek container health status
Write-Log "Tjekker container health status..."
$ContainerStatus = docker ps --format "table {{.Names}}\t{{.Status}}"
$UnhealthyContainers = $ContainerStatus | Select-String -Pattern "unhealthy"

if ($UnhealthyContainers) {
    Write-Log "Advarsel: Følgende containers er unhealthy:" "WARNING"
    $UnhealthyContainers | ForEach-Object { Write-Log "  $_" "WARNING" }
    $Continue = Read-Host "Fortsæt alligevel? [y/N]"
    if ($Continue -ne 'y') { exit 1 }
}

# Tjek disk plads
$DriveInfo = Get-PSDrive -Name (Split-Path -Qualifier $BackupPath)
$FreeSpaceGB = [math]::Round($DriveInfo.Free / 1GB, 2)
Write-Log "Ledig plads på backup drive: $FreeSpaceGB GB"

if ($FreeSpaceGB -lt 10) {
    Write-Log "Advarsel: Kun $FreeSpaceGB GB ledig plads!" "WARNING"
}

# 1. Stop containers for konsistent backup (valgfrit)
$StopContainers = Read-Host "Vil du stoppe containers for konsistent backup? (anbefalet) [Y/n]"
if ($StopContainers -ne 'n') {
    Write-Log "Stopper containers..."
    docker-compose down

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Fejl ved stop af containers" "ERROR"
        $ContinueAnyway = Read-Host "Fortsæt alligevel? [y/N]"
        if ($ContinueAnyway -ne 'y') { exit 1 }
    }

    $ContainersStopped = $true
} else {
    Write-Log "Containers kører stadig - backup kan være inkonsistent" "WARNING"
    $ContainersStopped = $false
}

# 2. Opret temp backup mappe
New-Item -ItemType Directory -Path $TempBackupDir -Force | Out-Null

# 3. Backup Docker volumes med progress bar
Write-Log "`nBackup af Docker volumes..."
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

    # Check om volume eksisterer
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
            Write-Host " FEJL" -ForegroundColor Red
            Write-Log "Volume backup fejlet: $Volume" "ERROR"
        }
    } else {
        Write-Host " IKKE FUNDET" -ForegroundColor Yellow
        Write-Log "Volume ikke fundet: $Volume" "WARNING"
    }
}

Write-Progress -Activity "Backing up Docker volumes" -Completed

# 4. Backup konfigurationsfiler
Write-Log "`nBackup af konfigurationsfiler..."
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
        Write-Log "Kopieret: $File"
    }
}

# 5. Backup scripts
if (Test-Path ".\scripts") {
    Write-Log "Backup af scripts..."
    Copy-Item -Path ".\scripts" -Destination "$TempBackupDir\scripts" -Recurse -Force
}

# 6. Backup data mappe struktur (uden media filer som standard)
Write-Log "`nBackup af data struktur..."
$DataBackupDir = "$TempBackupDir\data_structure"
New-Item -ItemType Directory -Path $DataBackupDir -Force | Out-Null

# Gem mappestruktur
Get-ChildItem -Path ".\data" -Recurse -Directory | ForEach-Object {
    $RelativePath = $_.FullName.Replace((Get-Location).Path + "\data\", "")
    New-Item -ItemType Directory -Path "$DataBackupDir\$RelativePath" -Force | Out-Null
}

# Gem en oversigt over indhold
Get-ChildItem -Path ".\data" -Recurse |
    Select-Object FullName, Length, LastWriteTime |
    Export-Csv -Path "$TempBackupDir\data_inventory.csv" -NoTypeInformation

# 7. Valgfri: Backup media filer
if ($IncludeMedia) {
    Write-Log "Inkluderer media filer (dette kan tage lang tid)..." "WARNING"

    $MediaSize = (Get-ChildItem -Path ".\data\media" -Recurse -File |
        Measure-Object -Property Length -Sum).Sum / 1GB

    Write-Host "Media størrelse: $([math]::Round($MediaSize, 2)) GB" -ForegroundColor Yellow
    $Confirm = Read-Host "Fortsæt? [y/N]"

    if ($Confirm -eq 'y') {
        robocopy ".\data\media" "$TempBackupDir\media" /E /MT:8 /R:1 /W:1 /NFL /NDL /NP /LOG+:$LogFile
    }
}

# 8. Eksporter Docker images liste
Write-Log "`nEksporterer Docker images liste..."
docker images --format "table {{.Repository}}:{{.Tag}}" | Out-File "$TempBackupDir\docker_images.txt"

# 9. System information
Write-Log "Gemmer system information..."
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

# 10. Start containers igen hvis de blev stoppet
if ($ContainersStopped) {
    Write-Log "`nGenstarter containers..."
    docker-compose up -d

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Containers genstartet OK" "SUCCESS"
    } else {
        Write-Log "Fejl ved genstart af containers!" "ERROR"
    }
}

# 11. Komprimer backup
if (!$CompressOnly) {
    Write-Log "`nKomprimerer backup..."
    $BackupFile = "$BackupPath\$BackupName.zip"

    # Brug Compress-Archive med bedre komprimering
    $ProgressPreference = 'SilentlyContinue'
    Compress-Archive -Path "$TempBackupDir\*" -DestinationPath $BackupFile -CompressionLevel Optimal
    $ProgressPreference = 'Continue'

    $BackupSize = [math]::Round((Get-Item $BackupFile).Length / 1MB, 2)
    Write-Log "Backup komprimeret: $BackupSize MB" "SUCCESS"

    # Fjern temp mappe
    Remove-Item -Path $TempBackupDir -Recurse -Force
}

# 12. Kryptering (valgfri)
if ($Encrypt) {
    Write-Log "`nKrypterer backup..."

    # Tjek om 7-Zip er installeret
    if (!(Test-Path $SevenZipPath)) {
        # Prøv alternative lokationer
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
                Write-Log "7-Zip fundet på: $Path"
                break
            }
        }

        if (!$Found) {
            Write-Log "7-Zip ikke fundet! Download fra https://www.7-zip.org/" "ERROR"
            Write-Log "Eller brug -SevenZipPath parameter" "ERROR"
            Write-Log "Fortsætter uden kryptering..." "WARNING"
        }
    }

    if (Test-Path $SevenZipPath) {
        # Konverter SecureString til plain text (kun til 7-Zip kommando)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

        # Krypter med 7-Zip
        $EncryptedFile = "$BackupPath\$BackupName.7z"
        & $SevenZipPath a -p"$PlainPassword" -mhe=on -mx=9 $EncryptedFile $BackupFile

        # Ryd password fra memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

        if ($LASTEXITCODE -eq 0) {
            # Slet original zip fil
            Remove-Item $BackupFile -Force
            $BackupFile = $EncryptedFile
            Write-Log "Backup krypteret OK" "SUCCESS"
        } else {
            Write-Log "Kryptering fejlet!" "ERROR"
        }
    }
}

# 13. Cloud upload (valgfri)
if ($UploadToCloud) {
    Write-Log "`nUploader til cloud storage..."

    # Tjek om rclone er installeret
    try {
        rclone version | Out-Null

        # Upload med progress
        Write-Host "Uploader til: $CloudRemote" -ForegroundColor Cyan
        rclone copy $BackupFile $CloudRemote --progress

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Cloud upload OK" "SUCCESS"

            # List filer i cloud
            Write-Log "Filer i cloud backup:"
            rclone ls $CloudRemote --max-depth 1 | Out-String | Write-Log
        } else {
            Write-Log "Cloud upload fejlet!" "ERROR"
        }
    } catch {
        Write-Log "Rclone ikke installeret! Download fra https://rclone.org/" "ERROR"
    }
}

# 14. Backup retention (slet gamle backups)
Write-Log "`nHåndterer backup retention ($RetentionDays dage)..."
$OldBackups = Get-ChildItem -Path $BackupPath -Filter "arr_stack_backup_*.*" |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) }

if ($OldBackups) {
    Write-Log "Sletter $($OldBackups.Count) gamle backups..."
    $OldBackups | ForEach-Object {
        Write-Log "  Sletter: $($_.Name)"
        Remove-Item $_.FullName -Force
    }
}

# 15. Verificer backup
Write-Log "`nVerificerer backup..."
if (Test-Path $BackupFile) {
    $BackupInfo = Get-Item $BackupFile

    # Test arkiv integritet
    try {
        if ($BackupFile.EndsWith('.zip')) {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $TestArchive = [System.IO.Compression.ZipFile]::OpenRead($BackupFile)
            $TestArchive.Dispose()
        } elseif ($BackupFile.EndsWith('.7z')) {
            & $SevenZipPath t $BackupFile | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "7z test failed" }
        }
        Write-Log "Backup verificeret OK" "SUCCESS"
    } catch {
        Write-Log "Backup verifikation fejlet!" "ERROR"
    }
}

# 16. Generer forbedret restore script
$RestoreScript = @'
# Auto-genereret restore script
param(
    [string]$BackupFile = "BACKUP_FILE_PLACEHOLDER",
    [switch]$SelectiveRestore = $false,
    [string[]]$VolumesToRestore = @()
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   ARR STACK RESTORE SYSTEM" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Verificer backup fil eksisterer
if (!(Test-Path $BackupFile)) {
    Write-Host "Backup fil ikke fundet: $BackupFile" -ForegroundColor Red
    exit 1
}

# Tjek ledig disk plads
$DriveInfo = Get-PSDrive -Name (Split-Path -Qualifier ".")
$FreeSpaceGB = [math]::Round($DriveInfo.Free / 1GB, 2)
Write-Host "Ledig plads: $FreeSpaceGB GB" -ForegroundColor Yellow

if ($FreeSpaceGB -lt 20) {
    Write-Host "Advarsel: Kun $FreeSpaceGB GB ledig plads!" -ForegroundColor Yellow
    $Continue = Read-Host "Fortsæt? [y/N]"
    if ($Continue -ne 'y') { exit 1 }
}

# Backup nuværende config
Write-Host "Laver backup af nuværende config..." -ForegroundColor Yellow
$PreRestoreBackup = ".\pre_restore_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $PreRestoreBackup -Force | Out-Null
Copy-Item "docker-compose.yml", ".env" -Destination $PreRestoreBackup -ErrorAction SilentlyContinue

Write-Host "Gendanner fra: $BackupFile" -ForegroundColor Yellow
$TempDir = ".\temp_restore_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Håndter krypterede filer
if ($BackupFile.EndsWith('.7z')) {
    Write-Host "Dekrypterer backup..." -ForegroundColor Yellow
    $7zipPath = "C:\Program Files\7-Zip\7z.exe"
    $Password = Read-Host "Indtast password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    & $7zipPath x -p"$PlainPassword" -o"$TempDir" $BackupFile
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
} else {
    # Udpak zip backup
    Expand-Archive -Path $BackupFile -DestinationPath $TempDir -Force
}

# Stop containers
Write-Host "Stopper containers..." -ForegroundColor Yellow
docker-compose down

# Vælg volumes til restore
if ($SelectiveRestore) {
    $AvailableVolumes = Get-ChildItem "$TempDir\*.tar.gz" | ForEach-Object { $_.BaseName }
    Write-Host "`nTilgængelige volumes:" -ForegroundColor Cyan
    $AvailableVolumes | ForEach-Object { Write-Host "  - $_" }

    if ($VolumesToRestore.Count -eq 0) {
        $VolumeSelection = Read-Host "`nIndtast volumes at gendanne (komma-separeret, eller 'all')"
        if ($VolumeSelection -eq 'all') {
            $VolumesToRestore = $AvailableVolumes
        } else {
            $VolumesToRestore = $VolumeSelection -split ',' | ForEach-Object { $_.Trim() }
        }
    }
} else {
    $VolumesToRestore = Get-ChildItem "$TempDir\*.tar.gz" | ForEach-Object { $_.BaseName }
}

# Gendan volumes
Write-Host "`nGendanner volumes..." -ForegroundColor Yellow
foreach ($Volume in $VolumesToRestore) {
    Write-Host "  - Gendanner: $Volume" -NoNewline

    if (Test-Path "$TempDir\$Volume.tar.gz") {
        docker run --rm `
            -v ${Volume}:/target `
            -v ${PWD}\${TempDir}:/source:ro `
            alpine `
            sh -c "cd /target && tar xzf /source/$Volume.tar.gz"

        if ($LASTEXITCODE -eq 0) {
            Write-Host " OK" -ForegroundColor Green
        } else {
            Write-Host " FEJL" -ForegroundColor Red
        }
    } else {
        Write-Host " IKKE FUNDET" -ForegroundColor Yellow
    }
}

# Gendan config filer
$RestoreConfigs = Read-Host "`nGendan config filer? [Y/n]"
if ($RestoreConfigs -ne 'n') {
    Copy-Item "$TempDir\configs\*" -Destination . -Force
    Write-Host "Config filer gendannet" -ForegroundColor Green
}

# Start containers
Write-Host "`nStarter containers..." -ForegroundColor Yellow
docker-compose up -d

# Ryd op
Remove-Item -Path $TempDir -Recurse -Force

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "        RESTORE FULDFØRT!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Pre-restore backup gemt i: $PreRestoreBackup" -ForegroundColor Cyan

# Tjek container status
Start-Sleep -Seconds 10
Write-Host "`nContainer status:" -ForegroundColor Cyan
docker ps --format "table {{.Names}}\t{{.Status}}"
'@

$RestoreScript -replace "BACKUP_FILE_PLACEHOLDER", $BackupFile |
    Out-File "$BackupPath\restore_$Date.ps1" -Encoding UTF8

# 17. Afslutning
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "        BACKUP FULDFØRT!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Backup fil: $BackupFile" -ForegroundColor Cyan
Write-Host "Størrelse: $BackupSize MB" -ForegroundColor Cyan
Write-Host "Log fil: $LogFile" -ForegroundColor Cyan
Write-Host "Restore script: $BackupPath\restore_$Date.ps1" -ForegroundColor Cyan

if ($Encrypt) {
    Write-Host "Kryptering: JA (7-Zip AES-256)" -ForegroundColor Yellow
}

if ($UploadToCloud) {
    Write-Host "Cloud backup: $CloudRemote" -ForegroundColor Cyan
}

Write-Host "`nTip: Kør restore med:" -ForegroundColor Yellow
Write-Host "  .\backups\restore_$Date.ps1" -ForegroundColor White
Write-Host "`nFor selective restore:" -ForegroundColor Yellow
Write-Host "  .\backups\restore_$Date.ps1 -SelectiveRestore" -ForegroundColor White

Write-Log "`nBackup proces fuldført!" "SUCCESS"

# Vis backup indhold
Write-Host "`nBackup indeholder:" -ForegroundColor Cyan
if (Test-Path $BackupFile) {
    if ($BackupFile.EndsWith('.zip')) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $Archive = [System.IO.Compression.ZipFile]::OpenRead($BackupFile)
        $Archive.Entries | Group-Object { Split-Path $_.FullName } |
            Select-Object Name, Count | Format-Table
        $Archive.Dispose()
    } elseif ($BackupFile.EndsWith('.7z')) {
        Write-Host "  [Krypteret arkiv - indhold beskyttet]" -ForegroundColor Magenta
    }
}
