# setup-backup-schedule.ps1
# Sets up automatic backup via Windows Task Scheduler

# Require administrator rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator rights!" -ForegroundColor Red
    Write-Host "Right-click and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "=== ARR Stack Backup Scheduler Setup ===" -ForegroundColor Cyan

# Variables
$TaskName = "ARR Stack Automatic Backup"
$ScriptPath = "D:\docker\scripts\1_Daily_Operations\backup-arr-stack-auto.ps1"
$BackupPath = "D:\docker\backups"

# Check if backup script exists
if (!(Test-Path $ScriptPath)) {
    Write-Host "Backup script not found: $ScriptPath" -ForegroundColor Red
    Write-Host "Make sure 'backup-arr-stack-auto.ps1' is in the folder 'D:\docker\scripts\1_Daily_Operations\'" -ForegroundColor Yellow
    exit 1
}

# Choose backup time
Write-Host "`nWhen should the backup run?" -ForegroundColor Yellow
Write-Host "1. Every night at 02:00 (recommended)"
Write-Host "2. Every night at 23:00"
Write-Host "3. Every Sunday at 02:00"
Write-Host "4. Custom time"

$Choice = Read-Host "Choose [1-4]"

switch ($Choice) {
    "1" { 
        $TriggerTime = "02:00"
        $Schedule = "Daily"
    }
    "2" { 
        $TriggerTime = "23:00"
        $Schedule = "Daily"
    }
    "3" { 
        $TriggerTime = "02:00"
        $Schedule = "Weekly"
        $DaysOfWeek = "Sunday"
    }
    "4" {
        $TriggerTime = Read-Host "Enter time (HH:MM)"
        $ScheduleChoice = Read-Host "Daily or Weekly? [D/W]"
        if ($ScheduleChoice -eq "W") {
            $Schedule = "Weekly"
            $DaysOfWeek = Read-Host "Which day? (Monday, Tuesday, etc.)"
        } else {
            $Schedule = "Daily"
        }
    }
    default {
        $TriggerTime = "02:00"
        $Schedule = "Daily"
    }
}

# Create scheduled task
Write-Host "`nCreating scheduled task..." -ForegroundColor Yellow

# Task action
$Action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -BackupPath `"$BackupPath`"" `
    -WorkingDirectory "D:\docker"

# Task trigger
if ($Schedule -eq "Daily") {
    $Trigger = New-ScheduledTaskTrigger -Daily -At $TriggerTime
} else {
    $Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DaysOfWeek -At $TriggerTime
}

# Task settings
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -DontStopOnIdleEnd

# Task principal (Runs as the logged user)
$Principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType S4U `
    -RunLevel Highest

# Remove existing task if it exists
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Register new task
try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Principal $Principal `
        -Description "Automatic backup of Docker ARR stack configs and volumes"
    
    Write-Host "`nScheduled task created!" -ForegroundColor Green
} catch {
    Write-Host "Error creating task: $_" -ForegroundColor Red
    exit 1
}

# Vis task info
Write-Host "`n=== Task Information ===" -ForegroundColor Cyan
Write-Host "Task Name: $TaskName"
Write-Host "Schedule: $Schedule at $TriggerTime"
Write-Host "Script: $ScriptPath"
Write-Host "Backup folder: $BackupPath"

# Test task
$TestNow = Read-Host "`nDo you want to test the backup now? [Y/n]"
if ($TestNow -ne 'n') {
    Write-Host "`nRunning test backup..." -ForegroundColor Yellow
    Start-ScheduledTask -TaskName $TaskName
    
    # Vent længere og check status
    Write-Host "Waiting for backup completion (this may take up to 30 seconds)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Check om backup kører
    $RunningTask = Get-ScheduledTask -TaskName $TaskName | Where-Object {$_.State -eq 'Running'}
    if ($RunningTask) {
        Write-Host "Backup is still running, waiting longer..." -ForegroundColor Yellow
        Start-Sleep -Seconds 20
    }
    
    $TaskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
    
    if ($TaskInfo.LastTaskResult -eq 0) {
        Write-Host "Test backup completed successfully!" -ForegroundColor Green
        Write-Host "Check log files in: $BackupPath" -ForegroundColor Cyan
        
        # Vis seneste backup fil
        $LatestBackup = Get-ChildItem "$BackupPath\arr_backup_*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($LatestBackup) {
            Write-Host "Latest backup: $($LatestBackup.Name) ($([math]::Round($LatestBackup.Length/1MB,2)) MB)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "Test backup failed! Task result code: $($TaskInfo.LastTaskResult)" -ForegroundColor Red
        Write-Host "Check log files for details." -ForegroundColor Yellow
    }
}

Write-Host "`n=== Setup Completed ===" -ForegroundColor Green
Write-Host "Backup will now run automatically $Schedule at $TriggerTime" -ForegroundColor Cyan
Write-Host "`nTo view/change the task:" -ForegroundColor Yellow
Write-Host "1. Open Task Scheduler (taskschd.msc)"
Write-Host "2. Find '$TaskName' under Task Scheduler Library"

# Opret restore script
$RestoreScriptContent = @'
# restore-latest-backup.ps1
param(
    [string]$BackupPath = "D:\docker\backups"
)

# Find nyeste backup
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

# Udpak backup
$TempDir = "$BackupPath\restore_temp"
Expand-Archive -Path $LatestBackup.FullName -DestinationPath $TempDir -Force

# Gendan config filer
Copy-Item "$TempDir\docker-compose.yml", "$TempDir\.env", "$TempDir\recyclarr.yml" -Destination "D:\docker\" -Force

# Gendan volumes
Get-ChildItem "$TempDir\*.tar.gz" | ForEach-Object {
    $VolumeName = $_.BaseName
    Write-Host "Restoring volume: $VolumeName" -ForegroundColor Yellow
    
    # Find det korrekte volume navn
    $ActualVolume = docker volume ls --format "{{.Name}}" | Where-Object { $_ -eq $VolumeName -or $_ -eq "docker_$VolumeName" }
    
    if($ActualVolume) {
        docker run --rm `
            -v "${ActualVolume}:/target" `
            -v "${TempDir}:/source:ro" `
            alpine sh -c "cd /target && tar xzf /source/$($_.Name)"
    } else {
        Write-Host "  Volume '$VolumeName' not found in Docker, skipping." -ForegroundColor Yellow
    }
}

# Start containers
Write-Host "Starting containers..." -ForegroundColor Yellow
docker-compose up -d

# Ryd op
Remove-Item -Path $TempDir -Recurse -Force

Write-Host "Restore completed!" -ForegroundColor Green
'@

$RestoreScriptPath = "D:\docker\scripts\1_Daily_Operations\restore-latest-backup.ps1"
if (-Not (Test-Path $RestoreScriptPath)) {
    $RestoreScriptContent | Out-File $RestoreScriptPath -Encoding UTF8
    Write-Host "`nRestore script created: $RestoreScriptPath" -ForegroundColor Cyan
}

Write-Host "`nAll done!" -ForegroundColor Green