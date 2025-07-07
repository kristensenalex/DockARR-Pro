# ARR Stack Docker Compose Setup

## 🎯 What is this?
A professional, portable docker-compose setup for your entire ARR stack with an enterprise-grade backup system. Includes Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Tdarr, qBittorrent, FlareSolverr, and Portainer – optimized for easy maintenance and cross-platform use.

---

## 🚀 Quick Start

> **Note:** If you downloaded these files from Claude, you'll need to rename two files first:
> - Rename `.gitignore.txt` → `.gitignore`
> - Rename `.env.example.txt` → `.env.example`

1. **Create your configuration file**

   Linux/macOS:
   ```bash
   cp .env.example .env
   ```

   Windows PowerShell:
   ```powershell
   Copy-Item .env.example .env
   ```

2. **Adjust the paths in `.env` for your system**
   - Linux: Use paths like `/mnt/docker/data`
   - Windows: Use paths like `D:\docker\data`

3. **Start the entire stack**
   ```bash
   docker compose up -d
   ```

4. **Verify everything is running**
   ```bash
   docker compose ps
   ```

---

## ✨ Features

### Core Features
- **Reusable YAML anchors**: Centralized configuration
- **Environment variable driven**: Everything is controlled from the `.env` file
- **Healthchecks**: On all critical services
- **Auto-updating**: Via Watchtower with granular control
- **Portainer EE**: Enterprise Docker management interface

### Backup System (v3.0)
- **Full volume backup**: All configs and data
- **Encryption**: AES-256 via 7-Zip
- **Cloud sync**: Automatic upload to Google Drive, OneDrive, etc.
- **Retention policies**: Automatic deletion of old backups
- **Selective restore**: Restore only specific volumes
- **Pre-flight checks**: Container health and disk space verification
- **Progress tracking**: Real-time status during backup
- **Notifications**: Discord/Slack webhook support

---

## 📦 Included Services

| Service       | Port  | Description           |
|---------------|-------|-----------------------|
| qBittorrent   | 8080  | Torrent client        |
| Prowlarr      | 9696  | Indexer manager       |
| Sonarr        | 8989  | TV series automation  |
| Radarr        | 7878  | Movie automation      |
| Lidarr        | 8686  | Music automation      |
| Bazarr        | 6767  | Subtitle automation   |
| FlareSolverr  | 8191  | Cloudflare bypass     |
| Tdarr         | 8265  | Media transcoding     |
| Portainer     | 9443  | Docker management     |
| Watchtower    | -     | Container updater     |

---

## 🔧 Configuration

### Basic .env Example
```env
# System
PUID=1000
PGID=1000
UMASK=002
TZ=Europe/Copenhagen

# Paths (adjust for your system)
DATA_PATH=/mnt/docker/data
TDARR_PLUGINS_PATH=/mnt/docker/tdarr/plugins
PORTAINER_LICENSE=/mnt/docker/portainer/portainer.lic

# Backup (optional)
BACKUP_NOTIFICATION_WEBHOOK=https://discord.com/api/webhooks/...
```

### Ports
All ports can be changed in `.env` if you have conflicts:
```env
SONARR_PORT=8989
RADARR_PORT=7878
# etc...
```

---

## 💾 Backup & Restore

### Automatic Backup
```powershell
# Standard backup
.\backup-arr-stack.ps1

# Encrypted backup
.\backup-arr-stack.ps1 -Encrypt -Password (Read-Host -AsSecureString)

# Backup with cloud upload
.\backup-arr-stack.ps1 -UploadToCloud -CloudRemote "gdrive:backups"

# Full backup incl. media
.\backup-arr-stack.ps1 -IncludeMedia -Encrypt -UploadToCloud

# Custom 7-Zip location
.\backup-arr-stack.ps1 -Encrypt -SevenZipPath "D:\Tools\7-Zip\7z.exe"
```

See [backup-arr-stack.ps1](backup-arr-stack.ps1) for full documentation of all backup options.

### Restore
```powershell
# Full restore
.\backups\restore_[date].ps1

# Selective restore
.\backups\restore_[date].ps1 -SelectiveRestore
```

### Scheduled Backup
Create a Windows Task or Linux cron job:
```bash
# Linux crontab example (daily at 3:00 AM)
0 3 * * * cd /path/to/arr-stack && pwsh backup-arr-stack.ps1 -UploadToCloud
```

---

## 🔄 Migration between systems

1. **On the source system:**
   ```powershell
   .\backup-arr-stack.ps1 -Encrypt
   ```

2. **Copy to the new system:**
   - The backup file
   - docker-compose.yml
   - .env (adjust paths!)

3. **On the target system:**
   ```powershell
   .\restore_[date].ps1
   ```

---

## 🔧 Updating Services

### Update all images to the latest version
```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Remove old unused images
docker image prune
```

### Update specific service
```bash
# Update only Sonarr
docker compose pull sonarr
docker compose up -d sonarr
```

### Rollback to previous version
Edit the image tag in `.env`:
```env
SONARR_IMAGE=lscr.io/linuxserver/sonarr:3.0.10
```
Then:
```bash
docker compose up -d sonarr
```

---

## 🛠️ Advanced Usage

### Only update specific services
Edit Watchtower labels in `docker-compose.yml`:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

### Add extra services
Use the existing YAML anchors:
```yaml
my-service:
  <<: *common-properties
  image: my/image:latest
  # ...
```

### Performance tuning
For Tdarr transcoding:
```yaml
tdarr:
  deploy:
    resources:
      reservations:
        devices:
          - capabilities: [gpu]
```

---

## 📊 Monitoring

### Container status
```bash
# See all containers
docker compose ps

# View logs for a specific service
docker compose logs -f sonarr

# See resource usage
docker stats
```

### Portainer Dashboard
Access Portainer at: https://localhost:9443

---

## 🚨 Troubleshooting

### Container won't start
```bash
# Check logs
docker compose logs [service-name]

# Restart service
docker compose restart [service-name]
```

### Permission issues
Verify PUID/PGID matches your user:
```bash
id $USER
```

### Disk space
```bash
# Check Docker volumes
docker system df

# Clean up
docker system prune -a
```

---

## 🔐 Security

- Never run as root (use PUID/PGID)
- Use strong passwords
- Enable 2FA in Portainer
- Consider VPN for remote access
- Keep images updated via Watchtower

---

## 📚 Links

- [LinuxServer.io Docs](https://docs.linuxserver.io)
- [Servarr Wiki](https://wiki.servarr.com)
- [TRaSH Guides](https://trash-guides.info)

---

## 🤝 Support

Having issues or suggestions?
- Create a GitHub issue
- Check logs first: `docker compose logs`
- Include your `.env` (without passwords!) and `docker compose ps` output

---

## 📝 Changelog

### v3.0 (2024)
- Added advanced backup system
- Portainer data volume
- Tdarr cache volume  
- FlareSolverr healthcheck
- Improved documentation

### v2.0
- YAML anchor implementation
- Environment variable-driven config
- Cross-platform support

### v1.0
- Initial release
