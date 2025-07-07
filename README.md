# ARR Stack Docker Compose Setup

## 🎯 Hvad er dette?
Et professionelt, portabelt docker-compose setup til hele din ARR-stack med enterprise-grade backup system. Inkluderer Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Tdarr, qBittorrent, FlareSolverr og Portainer - optimeret til nem vedligeholdelse og cross-platform brug.

---

## 🚀 Hurtig Start

1. **Kopier `.env.example` til `.env` og tilpas værdierne**  
   
   Linux/macOS:
   ```bash
   cp .env.example .env
   ```
   
   Windows PowerShell:
   ```powershell
   Copy-Item .env.example .env
   ```
   
   - Linux: Brug stier som `/mnt/docker/data`
   - Windows: Brug stier som `D:\docker\data`

2. **Start hele stacken**
   ```bash
   docker compose up -d
   ```

3. **Verificer at alt kører**
   ```bash
   docker compose ps
   ```

---

## ✨ Features

### Core Features
- **Genanvendelige YAML-ankre**: Centraliseret konfiguration
- **Miljøvariabel-drevet**: Alt styres fra `.env` filen
- **Healthchecks**: På alle kritiske services
- **Auto-opdatering**: Via Watchtower med granular kontrol
- **Portainer EE**: Enterprise Docker management interface

### Backup System (v3.0)
- **Fuld volume backup**: Alle configs og data
- **Kryptering**: AES-256 via 7-Zip
- **Cloud sync**: Automatisk upload til Google Drive, OneDrive, etc.
- **Retention policies**: Automatisk sletning af gamle backups
- **Selective restore**: Gendan kun specifikke volumes
- **Pre-flight checks**: Container health og disk plads verifikation
- **Progress tracking**: Real-time status under backup
- **Notifikationer**: Discord/Slack webhook support

---

## 📦 Inkluderede Services

| Service | Port | Beskrivelse |
|---------|------|-------------|
| qBittorrent | 8080 | Torrent klient |
| Prowlarr | 9696 | Indexer manager |
| Sonarr | 8989 | TV serie automation |
| Radarr | 7878 | Film automation |
| Lidarr | 8686 | Musik automation |
| Bazarr | 6767 | Undertekst automation |
| FlareSolverr | 8191 | Cloudflare bypass |
| Tdarr | 8265 | Media transcoding |
| Portainer | 9443 | Docker management |
| Watchtower | - | Container updater |

---

## 🔧 Konfiguration

### Basis .env Eksempel
```env
# System
PUID=1000
PGID=1000
UMASK=002
TZ=Europe/Copenhagen

# Paths (tilpas til dit system)
DATA_PATH=/mnt/docker/data
TDARR_PLUGINS_PATH=/mnt/docker/tdarr/plugins
PORTAINER_LICENSE=/mnt/docker/portainer/portainer.lic

# Backup (valgfri)
BACKUP_NOTIFICATION_WEBHOOK=https://discord.com/api/webhooks/...
```

### Porte
Alle porte kan ændres i `.env` hvis du har konflikter:
```env
SONARR_PORT=8989
RADARR_PORT=7878
# osv...
```

---

## 💾 Backup & Restore

### Automatisk Backup
```powershell
# Standard backup
.\backup-arr-stack.ps1

# Krypteret backup
.\backup-arr-stack.ps1 -Encrypt -Password (Read-Host -AsSecureString)

# Backup med cloud upload
.\backup-arr-stack.ps1 -UploadToCloud -CloudRemote "gdrive:backups"

# Fuld backup inkl. media
.\backup-arr-stack.ps1 -IncludeMedia -Encrypt -UploadToCloud

# Custom 7-Zip lokation
.\backup-arr-stack.ps1 -Encrypt -SevenZipPath "D:\Tools\7-Zip\7z.exe"
```

Se [backup-arr-stack.ps1](backup-arr-stack.ps1) for komplet dokumentation af alle backup muligheder.

### Restore
```powershell
# Fuld restore
.\backups\restore_[dato].ps1

# Selective restore
.\backups\restore_[dato].ps1 -SelectiveRestore
```

### Scheduled Backup
Opret en Windows Task eller Linux cron job:
```bash
# Linux crontab eksempel (daglig kl. 3:00)
0 3 * * * cd /path/to/arr-stack && pwsh backup-arr-stack.ps1 -UploadToCloud
```

---

## 🔄 Migration mellem systemer

1. **På kilde system:**
   ```powershell
   .\backup-arr-stack.ps1 -Encrypt
   ```

2. **Kopier til nyt system:**
   - Backup filen
   - docker-compose.yml
   - .env (tilpas stier!)

3. **På destination system:**
   ```powershell
   .\restore_[dato].ps1
   ```

---

## 🔧 Opdatering af Services

### Opdater alle images til nyeste version
```bash
# Pull nyeste images
docker compose pull

# Genstart med nye images
docker compose up -d

# Fjern gamle unused images
docker image prune
```

### Opdater specifik service
```bash
# Opdater kun Sonarr
docker compose pull sonarr
docker compose up -d sonarr
```

### Rollback til tidligere version
Rediger image tag i `.env`:
```env
SONARR_IMAGE=lscr.io/linuxserver/sonarr:3.0.10
```
Derefter:
```bash
docker compose up -d sonarr
```

---

## 🛠️ Avanceret Brug

### Kun opdater specifikke services
Rediger Watchtower labels i `docker-compose.yml`:
```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

### Tilføj ekstra services
Brug de eksisterende YAML ankre:
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
# Se alle containers
docker compose ps

# Se logs for specifik service
docker compose logs -f sonarr

# Se resource forbrug
docker stats
```

### Portainer Dashboard
Tilgå Portainer på: https://localhost:9443

---

## 🚨 Troubleshooting

### Container starter ikke
```bash
# Check logs
docker compose logs [service-navn]

# Genstart service
docker compose restart [service-navn]
```

### Permission problemer
Verificer PUID/PGID matcher din bruger:
```bash
id $USER
```

### Disk plads
```bash
# Check Docker volumes
docker system df

# Ryd op
docker system prune -a
```

---

## 🔐 Sikkerhed

- Kør aldrig som root (brug PUID/PGID)
- Brug stærke passwords
- Aktiver 2FA i Portainer
- Overvej VPN for remote access
- Hold images opdateret via Watchtower

---

## 📚 Links

- [LinuxServer.io Docs](https://docs.linuxserver.io)
- [Servarr Wiki](https://wiki.servarr.com)
- [TRaSH Guides](https://trash-guides.info)

---

## 🤝 Support

Har du problemer eller forslag?
- Opret et GitHub issue
- Check logs først: `docker compose logs`
- Inkluder din `.env` (uden passwords!) og `docker compose ps` output

---

## 📝 Changelog

### v3.0 (2024)
- Tilføjet avanceret backup system
- Portainer data volume
- Tdarr cache volume  
- FlareSolverr healthcheck
- Forbedret dokumentation

### v2.0
- YAML ankre implementation
- Miljøvariabel-drevet config
- Cross-platform support

### v1.0
- Initial release