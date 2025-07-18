# setup_folders.ps1 - Creates complete folder structure for ARR stack
# Updated with all new services

Write-Host "Creating folder structure for ARR stack..." -ForegroundColor Cyan

$basePath = "D:\docker\data"

# Define folder structure
$folders = @(
    # Media libraries
    "$basePath\media\tv",
    "$basePath\media\movies", 
    "$basePath\media\music",
    
    # Downloads - torrents folders
    "$basePath\torrents\complete",
    "$basePath\torrents\incomplete",
    "$basePath\torrents\watch",
    
    # Transcode cache for Tdarr
    "$basePath\tdarr_cache",
    
    # Recycle bins - matches your naming
    "$basePath\recycle\tv",
    "$basePath\recycle\movies",
    "$basePath\recycle\music",
    
    # Backup folder
    "D:\docker\backups",
    
    # Scripts folders
    "D:\docker\scripts\1_Daily_Operations",
    "D:\docker\scripts\2_Manual_Control",
    "D:\docker\scripts\3_Initial_Setup",
    
    # Tdarr plugins
    "D:\docker\tdarr\plugins",
    
    # Logs folder
    "D:\docker\logs"
)

# Create folders
foreach ($folder in $folders) {
    if (-Not (Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
        Write-Host "[OK] Created: $folder" -ForegroundColor Green
    } else {
        Write-Host "[Exists] $folder" -ForegroundColor Yellow
    }
}

# Create .gitkeep files in empty folders
$gitkeepFolders = @(
    "D:\docker\logs",
    "D:\docker\tdarr\plugins"
)

foreach ($folder in $gitkeepFolders) {
    $gitkeepFile = Join-Path $folder ".gitkeep"
    if (-Not (Test-Path $gitkeepFile)) {
        New-Item -Path $gitkeepFile -ItemType File -Force | Out-Null
        Write-Host "[OK] Created .gitkeep in: $folder" -ForegroundColor Gray
    }
}

# Show folder structure
Write-Host ""
Write-Host "Folder structure:" -ForegroundColor Magenta
tree /F D:\docker\data | Select-Object -First 30

Write-Host ""
Write-Host "Docker folder structure:" -ForegroundColor Magenta
tree D:\docker\scripts

Write-Host ""
Write-Host "Folder structure created!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run mount_synology_drives.ps1 to map NAS shares" -ForegroundColor Cyan
Write-Host "2. Configure .env file with your paths and API keys" -ForegroundColor Cyan
Write-Host "3. Start the stack with: docker-compose up -d" -ForegroundColor Cyan