# mount_synology_drives.ps1 - Maps Synology shares as network drives

Write-Host "Mapping Synology network drives..." -ForegroundColor Cyan

# Configuration - adjust these values
$nasIP = "192.168.1.43"  # Your Synology IP
$nasUser = "kristensen"  # Your Synology username

# Define mappings
$mappings = @(
    @{Drive="Y:"; Path="\\$nasIP\Plex\Media\Movies"; Name="Movies"},
    @{Drive="Z:"; Path="\\$nasIP\Plex\Media\TV-shows"; Name="TV-shows"},
    @{Drive="X:"; Path="\\$nasIP\Plex\Media\Music"; Name="Music"}
)

# Iterate through all mappings
foreach ($map in $mappings) {
    if (Test-Path $map.Drive) {
        Write-Host "[OK] $($map.Drive) is already mapped to $($map.Name)" -ForegroundColor Yellow
    } else {
        Write-Host "Mapping $($map.Drive) to $($map.Path)..." -ForegroundColor White
        
        # Map network drive (will ask for password the first time)
        $result = net use $map.Drive $map.Path /persistent:yes 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $($map.Drive) mapped successfully!" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Could not map $($map.Drive): $result" -ForegroundColor Red
        }
    }
}

# Show all mapped drives
Write-Host ""
Write-Host "Current network drives:" -ForegroundColor Magenta
net use

Write-Host ""
Write-Host "Tip: If you want to remove a mapping, use: net use Y: /delete" -ForegroundColor Cyan
Write-Host "Tip: To save credentials permanently: use Windows Credential Manager" -ForegroundColor Cyan