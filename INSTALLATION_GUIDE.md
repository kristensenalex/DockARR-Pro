# 🚀 Enterprise ARR Stack - Complete Installation & User Guide

[![Docker](https://img.shields.io/badge/Docker-20.10+-blue?logo=docker)](https://www.docker.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue?logo=powershell)](https://docs.microsoft.com/en-us/powershell/)
[![VPN](https://img.shields.io/badge/VPN-Mullvad%20WireGuard-green?logo=wireguard)](https://mullvad.net/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **A complete, enterprise-grade media server stack with VPN protection, automated backups, and professional management tools.**

## 📋 Table of Contents

- [🎯 Overview](#-overview)
- [✨ Features](#-features)
- [⚙️ System Requirements](#️-system-requirements)
- [🚀 Quick Start](#-quick-start)
- [📖 Detailed Installation](#-detailed-installation)
- [🔧 Configuration](#-configuration)
- [📱 Service Access](#-service-access)
- [🛠️ Management](#️-management)
- [🔒 Security](#-security)
- [📦 Backup & Restore](#-backup--restore)
- [🔧 Troubleshooting](#-troubleshooting)
- [📚 Advanced Configuration](#-advanced-configuration)
- [🆘 Support](#-support)

---

## 🎯 Overview

This enterprise ARR stack provides a complete, VPN-protected media server solution with:

- **🔒 VPN Protection**: All download traffic routed through Mullvad WireGuard
- **📺 Complete Media Management**: TV shows, movies, music, and subtitles
- **🤖 Automation**: Quality profiles, content requests, and transcoding
- **📦 Enterprise Features**: Automated backups, monitoring, and management
- **🛡️ Security**: Health checks, resource limits, and secure defaults

### 📊 Architecture

```
┌─────────────────┐    ┌──────────────┐    ┌─────────────────┐
│   Overseerr     │    │   Portainer  │    │   Tdarr         │
│   (Requests)    │    │   (Manage)   │    │   (Transcode)   │
└─────────────────┘    └──────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
              ┌──────────────────────────────────────────┐
              │            VPN Network (Gluetun)         │
              │  ┌─────────┬─────────┬─────────┬───────┐ │
              │  │Transmis.│ Prowlarr│ Sonarr  │Radarr │ │
              │  │         │         │         │       │ │
              │  │ Lidarr  │ Bazarr  │Recyclarr│FlareSR│ │
              │  └─────────┴─────────┴─────────┴───────┘ │
              └──────────────────────────────────────────┘
                              │
                    ┌─────────────────┐
                    │ Mullvad VPN     │
                    │ WireGuard       │
                    └─────────────────┘
```

---

## ✨ Features

### 🎬 Media Management
- **Sonarr**: TV series management and monitoring
- **Radarr**: Movie collection management
- **Lidarr**: Music library management
- **Bazarr**: Subtitle downloading and management

### 🔍 Content Discovery
- **Prowlarr**: Indexer management for all *arr services
- **Overseerr**: User-friendly content request system

### 📥 Downloading
- **Transmission**: BitTorrent client with VPN protection
- **FlareSolverr**: Cloudflare bypass for problematic indexers

### 🎞️ Media Processing
- **Tdarr**: Automated media transcoding and optimization
- **Custom Plugins**: Pre-configured transcoding workflows

### 🔧 System Management
- **Portainer**: Docker container management UI
- **Watchtower**: Automated container updates
- **Recyclarr**: Quality profile synchronization

### 🛡️ Security & Monitoring
- **Gluetun VPN**: Mullvad WireGuard integration
- **Health Checks**: Comprehensive service monitoring
- **Resource Limits**: Memory and CPU constraints
- **Automated Backups**: Daily configuration backups

---

## ⚙️ System Requirements

### 🖥️ Hardware Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **CPU** | 4 cores | 8+ cores | For transcoding |
| **RAM** | 8 GB | 16+ GB | Multiple services |
| **Storage** | 100 GB | 1+ TB | Media library |
| **Network** | 100 Mbps | 1 Gbps | Download speed |

### 💻 Software Requirements

- **OS**: Windows 10/11 (64-bit)
- **Docker Desktop**: 4.0+ with WSL2 backend
- **PowerShell**: 5.1+ (Built into Windows)
- **VPN**: Active Mullvad subscription

### 🌐 Network Requirements

#### Required Ports
- `5055`: Overseerr (Requests)
- `6767`: Bazarr (Subtitles)
- `7878`: Radarr (Movies)
- `8191`: FlareSolverr (Cloudflare bypass)
- `8265-8266`: Tdarr (Transcoding)
- `8686`: Lidarr (Music)
- `8989`: Sonarr (TV Shows)
- `9091`: Transmission (Downloads)
- `9443`: Portainer (Management)
- `9696`: Prowlarr (Indexers)
- `51413`: Transmission P2P

#### VPN Requirements
- **Mullvad Account**: [Sign up here](https://mullvad.net/account/#/create)
- **WireGuard Config**: Generated from Mullvad account
- **Active Subscription**: Required for VPN functionality

---

## 🚀 Quick Start

### 🎯 One-Command Installation

1. **Download Superinstaller**:
   ```powershell
   # Download to Desktop
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/your-repo/enterprise-arr-stack/main/superinstaller.ps1" -OutFile "$env:USERPROFILE\Desktop\superinstaller.ps1"
   ```

2. **Run as Administrator**:
   ```powershell
   # Right-click PowerShell -> Run as Administrator
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   cd "$env:USERPROFILE\Desktop"
   .\superinstaller.ps1
   ```

3. **Follow the Interactive Setup** - The installer will guide you through everything!

### ⚡ Quick Install Options

```powershell
# Interactive installation (recommended for first-time users)
.\superinstaller.ps1

# Quick install with defaults (experienced users)
.\superinstaller.ps1 -QuickInstall

# Custom installation path
.\superinstaller.ps1 -InstallPath "D:\MediaServer"

# Skip prerequisites check (if Docker already installed)
.\superinstaller.ps1 -SkipPrerequisites
```

---

## 📖 Detailed Installation

### 📋 Step-by-Step Installation

#### Step 1: Prerequisites Check
The installer automatically verifies:
- ✅ Administrator privileges
- ✅ Docker Desktop installation
- ✅ Port availability
- ✅ System resources

#### Step 2: Docker Setup
If Docker isn't installed:
1. Download from [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Install with WSL2 backend
3. Restart and enable Docker
4. Re-run the installer

#### Step 3: Installation Process
The installer will:
1. **Create Directory Structure**
   ```
   C:\ARR-Stack\
   ├── data\
   │   ├── media\
   │   ├── torrents\
   │   └── tdarr_cache\
   ├── scripts\
   ├── backups\
   └── logs\
   ```

2. **Generate Configuration Files**
   - `docker-compose.yml`: Service definitions
   - `.env`: Environment variables
   - Management scripts

3. **Configure Environment**
   - Timezone setup
   - Authentication credentials
   - File paths

4. **Start Services**
   - Pull Docker images
   - Start containers
   - Verify health status

#### Step 4: Post-Installation
After installation completes:
1. Configure Mullvad VPN credentials
2. Set up API keys for each service
3. Configure service integrations
4. Test functionality

---

## 🔧 Configuration

### 🔐 VPN Configuration (Critical!)

1. **Get Mullvad Credentials**:
   - Log into [Mullvad Account](https://mullvad.net/account/)
   - Go to WireGuard configuration
   - Generate a new key pair
   - Note the private key and IP address

2. **Update .env File**:
   ```env
   # Open C:\ARR-Stack\.env in notepad
   MULLVAD_PRIVATE_KEY=your_actual_private_key_here
   MULLVAD_ADDRESSES=10.x.x.x/32
   ```

3. **Restart VPN Container**:
   ```powershell
   cd C:\ARR-Stack
   docker-compose restart gluetun
   ```

### 🔑 API Key Configuration

Each service needs API keys for integration:

1. **Access Each Service** (see [Service Access](#-service-access))
2. **Generate API Keys**:
   - Go to Settings → General → Security
   - Generate/copy API key
   - Add to `.env` file

3. **Required API Keys**:
   ```env
   PROWLARR_API_KEY=your_prowlarr_api_key
   SONARR_API_KEY=your_sonarr_api_key
   RADARR_API_KEY=your_radarr_api_key
   LIDARR_API_KEY=your_lidarr_api_key
   BAZARR_API_KEY=your_bazarr_api_key
   ```

### 🔗 Service Integration

#### Configure Download Client (Transmission)
In each *arr service:
1. Settings → Download Clients → Add → Transmission
2. **Host**: `transmission` (container name)
3. **Port**: `9091`
4. **Username/Password**: From your `.env` file

#### Configure Indexer Management (Prowlarr)
1. Add indexers in Prowlarr
2. Configure *arr app integration:
   - Sonarr: `http://sonarr:8989`
   - Radarr: `http://radarr:7878`
   - Lidarr: `http://lidarr:8686`

---

## 📱 Service Access

### 🌐 Web Interfaces

| Service | URL | Purpose | Default Login |
|---------|-----|---------|---------------|
| **Overseerr** | http://localhost:5055 | Request movies/shows | Setup on first visit |
| **Transmission** | http://localhost:9091 | Torrent management | From .env file |
| **Sonarr** | http://localhost:8989 | TV show management | No auth required |
| **Radarr** | http://localhost:7878 | Movie management | No auth required |
| **Lidarr** | http://localhost:8686 | Music management | No auth required |
| **Bazarr** | http://localhost:6767 | Subtitle management | No auth required |
| **Prowlarr** | http://localhost:9696 | Indexer management | No auth required |
| **Tdarr** | http://localhost:8265 | Transcoding | No auth required |
| **Portainer** | https://localhost:9443 | Container management | Create on first visit |

### 📱 Mobile Access

All services are accessible from mobile devices on your local network:
- Replace `localhost` with your computer's IP address
- Example: `http://192.168.1.100:5055`

---

## 🛠️ Management

### 📊 System Status

Check system status with the built-in script:
```powershell
cd C:\ARR-Stack
.\scripts\2_Manual_Control\status.ps1
```

**Sample Output**:
```
🐳 Container Status:
transmission   Up 2 hours (healthy)
sonarr         Up 2 hours (healthy)
radarr         Up 2 hours (healthy)

🔒 VPN Status:
VPN IP: 198.54.135.105

💾 Disk Usage:
Data folder: 1.2 TB
Backups: 150 MB
```

### 🔧 Common Management Tasks

#### Start All Services
```powershell
cd C:\ARR-Stack
docker-compose up -d
```

#### Stop All Services
```powershell
cd C:\ARR-Stack
docker-compose down
```

#### Restart Single Service
```powershell
cd C:\ARR-Stack
docker-compose restart sonarr
```

#### View Logs
```powershell
cd C:\ARR-Stack
docker-compose logs sonarr
```

#### Update All Images
```powershell
cd C:\ARR-Stack
docker-compose pull
docker-compose up -d
```

### 📈 Resource Monitoring

#### Container Resource Usage
```powershell
docker stats
```

#### System Resource Usage
```powershell
# Check memory usage
Get-Process -Name "*docker*" | Select-Object Name, WorkingSet

# Check disk space
Get-PSDrive C | Select-Object Used, Free
```

---

## 🔒 Security

### 🛡️ VPN Protection

**All download traffic is protected** by Mullvad VPN:
- Transmission runs inside VPN container
- All *arr services route through VPN
- DNS leak protection enabled
- Kill-switch functionality

**Verify VPN Protection**:
```powershell
# Check external IP
docker exec transmission wget -qO- http://httpbin.org/ip
```

### 🔐 Network Security

- **Isolated Network**: Services run in isolated Docker network
- **No Direct Internet**: Download services can't bypass VPN
- **Internal Communication**: Services communicate via container names
- **Port Exposure**: Only necessary ports exposed to host

### 🔑 Authentication

- **Transmission**: Username/password authentication
- **Portainer**: Admin account setup required
- **API Keys**: All services use API key authentication
- **No Default Passwords**: All passwords must be configured

### 📝 Security Best Practices

1. **Change Default Passwords**: Update all credentials in `.env`
2. **Regular Updates**: Keep containers updated
3. **Monitor Logs**: Check for unusual activity
4. **VPN Status**: Verify VPN is always connected
5. **Backup Encryption**: Consider encrypting backup files

---

## 📦 Backup & Restore

### 🔄 Automated Backups

**Daily automated backups** are pre-configured:
- **Schedule**: Every night at 23:00
- **Retention**: 7 days
- **Contents**: All service configurations
- **Location**: `C:\ARR-Stack\backups\`

### 📥 Manual Backup

```powershell
cd C:\ARR-Stack
.\scripts\1_Daily_Operations\backup-arr-stack-auto.ps1
```

**Backup includes**:
- All Docker volumes
- Configuration files
- Environment settings
- Custom scripts

### 📤 Restore Process

1. **Stop Services**:
   ```powershell
   cd C:\ARR-Stack
   docker-compose down
   ```

2. **Run Restore Script**:
   ```powershell
   .\scripts\1_Daily_Operations\restore-latest-backup.ps1
   ```

3. **Restart Services**:
   ```powershell
   docker-compose up -d
   ```

### 💾 Backup Storage

- **Local**: Automatic local backup retention
- **Cloud**: Manual cloud backup options
- **External**: Copy to external drives

---

## 🔧 Troubleshooting

### 🚨 Common Issues

#### VPN Not Working
**Symptoms**: Downloads not starting, IP not changing
**Solutions**:
1. Check Mullvad credentials in `.env`
2. Verify account has active subscription
3. Restart gluetun container:
   ```powershell
   docker-compose restart gluetun
   ```

#### Services Can't Connect
**Symptoms**: *arr services can't reach Transmission
**Solutions**:
1. Ensure all services are running: `docker ps`
2. Check VPN container is healthy
3. Verify container network communication:
   ```powershell
   docker exec sonarr ping transmission
   ```

#### Port Conflicts
**Symptoms**: Services won't start, port errors
**Solutions**:
1. Check what's using ports: `netstat -an | findstr :9091`
2. Stop conflicting applications
3. Update port mappings in `.env`

#### Container Won't Start
**Symptoms**: Container exits immediately
**Solutions**:
1. Check logs: `docker-compose logs servicename`
2. Check file permissions on volumes
3. Verify environment variables in `.env`

### 🔍 Diagnostic Commands

```powershell
# Check all container status
docker-compose ps

# View container logs
docker-compose logs -f servicename

# Check VPN status
docker exec gluetun sh -c "wget -qO- http://httpbin.org/ip"

# Test internal connectivity
docker exec sonarr ping transmission

# Check disk space
df -h

# Check memory usage
docker stats --no-stream
```

### 📞 Getting Help

1. **Check Logs**: Always check container logs first
2. **Community Forums**: Reddit r/sonarr, r/radarr, r/docker
3. **GitHub Issues**: Report bugs on service repositories
4. **Documentation**: Official service documentation

---

## 📚 Advanced Configuration

### 🎛️ Performance Tuning

#### Transmission Optimization
```env
# In .env file
TRANSMISSION_PEER_LIMIT_GLOBAL=240
TRANSMISSION_PEER_LIMIT_PER_TORRENT=60
TRANSMISSION_SPEED_LIMIT_DOWN=0    # Unlimited
TRANSMISSION_SPEED_LIMIT_UP=1000   # 1MB/s upload limit
```

#### Memory Allocation
```yaml
# In docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G      # Maximum memory
    reservations:
      memory: 1G      # Reserved memory
```

### 🔧 Custom Configurations

#### Add Custom Indexers
1. Access Prowlarr at http://localhost:9696
2. Settings → Indexers → Add Indexer
3. Configure private tracker settings
4. Test connection and save

#### Custom Quality Profiles
1. Access Sonarr/Radarr
2. Settings → Profiles → Quality Profiles
3. Create custom profiles for different media types
4. Set up release profiles for preferred sources

#### Advanced Tdarr Workflows
1. Access Tdarr at http://localhost:8265
2. Libraries → Add library
3. Create custom transcode workflows
4. Set up GPU acceleration if available

### 🌍 Remote Access

#### Reverse Proxy Setup
For secure remote access, consider setting up:
- **Nginx Proxy Manager**
- **Traefik**
- **Cloudflare Tunnel**

#### VPN Access
Access your stack remotely via:
- **WireGuard VPN** to your home network
- **TeamViewer** or similar remote desktop
- **SSH tunnel** for command-line access

---

## 🆘 Support

### 📖 Documentation

- **Docker Compose**: [Official Docs](https://docs.docker.com/compose/)
- **Sonarr**: [Wiki](https://wiki.servarr.com/sonarr)
- **Radarr**: [Wiki](https://wiki.servarr.com/radarr)
- **Lidarr**: [Wiki](https://wiki.servarr.com/lidarr)
- **Bazarr**: [Wiki](https://wiki.bazarr.media/)
- **Prowlarr**: [Wiki](https://wiki.servarr.com/prowlarr)

### 💬 Community

- **Reddit**: r/sonarr, r/radarr, r/selfhosted
- **Discord**: TRaSH Guides Discord
- **GitHub**: Individual project repositories

### 🐛 Issue Reporting

When reporting issues, include:
1. **System Information**: OS, Docker version
2. **Error Messages**: Full error text
3. **Log Files**: Relevant container logs
4. **Configuration**: Sanitized .env file
5. **Steps to Reproduce**: Detailed reproduction steps

### 📝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Submit a pull request with detailed description

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **LinuxServer.io**: For excellent Docker images
- **Servarr Team**: For the amazing *arr applications
- **Community**: For continuous support and contributions

---

**🎉 Enjoy your Enterprise ARR Stack!**

*For the latest updates and releases, visit our [GitHub repository](https://github.com/your-repo/enterprise-arr-stack).*
