# restore-latest-backup.ps1 - Restore the latest backup for ARR stack
param(
    [string]$BackupPath = "D:\docker\backups"
)

# Find latest backup
$LatestBackup = Get-ChildItem -Path $BackupPath -Filter "arr_backup_*.zip" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (!$LatestBackup) {
    Write-Host "No backup found!" -ForegroundColor Red
    exit 1
}

Write-Host "Found backup: $($LatestBackup.Name)" -ForegroundColor Cyan
Write-Host "Date: $($LatestBackup.LastWriteTime)" -ForegroundColor Cyan

$Confirm = Read-Host "Restore from this backup? [y/N]"
if ($Confirm -ne 'y') { exit }

# Stop containers
Write-Host "Stopping containers..." -ForegroundColor Yellow
Set-Location D:\docker
docker-compose down

# Extract backup
$TempDir = "$BackupPath\restore_temp"
Expand-Archive -Path $LatestBackup.FullName -DestinationPath $TempDir -Force

# Restore config files
Copy-Item "$TempDir\docker-compose.yml", "$TempDir\.env", "$TempDir\recyclarr.yml" -Destination "D:\docker\" -Force

# Restore volumes
Get-ChildItem "$TempDir\*.tar.gz" | ForEach-Object {
    $VolumeName = $_.BaseName
    Write-Host "Restoring volume: $VolumeName" -ForegroundColor Yellow
    
    docker run --rm `
        -v "${VolumeName}:/target" `
        -v "${TempDir}:/source:ro" `
        alpine sh -c "cd /target && tar xzf /source/$($_.Name)"
}

# Start containers
Write-Host "Starting containers..." -ForegroundColor Yellow
docker-compose up -d

# Clean up
Remove-Item -Path $TempDir -Recurse -Force

Write-Host "✔ Restore completed!" -ForegroundColor Green
