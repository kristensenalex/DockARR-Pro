Write-Host "Navigating to docker folder..." -ForegroundColor Cyan
cd D:\docker

Write-Host "Stopping and removing current stack..." -ForegroundColor Yellow
docker-compose down

Write-Host "Pulling latest images..." -ForegroundColor Cyan
docker-compose pull

Write-Host "Starting ARR stack..." -ForegroundColor Green
docker-compose up -d

Write-Host "`nActive containers:" -ForegroundColor Magenta
docker ps