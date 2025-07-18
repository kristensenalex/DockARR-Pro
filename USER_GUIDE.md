# 📖 Enterprise ARR Stack - User Guide

> **Quick reference for daily use of your media server system**

## 🚀 Get Started (5 minutes)

### 1. Start the System
```powershell
# Open PowerShell as Administrator
cd C:\ARR-Stack
docker-compose up -d
```

### 2. Check Everything is Running
```powershell
.\scripts\2_Manual_Control\status.ps1
```

### 3. Access Services
- **Overseerr** (request movies/series): http://localhost:5055
- **Transmission** (downloads): http://localhost:9091
- **Portainer** (administration): https://localhost:9443

---

## 🎬 How Do You Use the System?

### 📺 Request New Content

1. **Go to Overseerr**: http://localhost:5055
2. **Search** for a movie or TV series
3. **Click "Request"** - the system does the rest automatically!

### 📊 Monitor Downloads

1. **Go to Transmission**: http://localhost:9091
   - **Username/Password**: As set during installation
2. **See download status** for your torrents
3. **When finished**: Automatically moved to your media library

### 🎯 Manage Collections

| Service   | Access                  | Purpose      |
|-----------|-------------------------|--------------|
| **Sonarr**| http://localhost:8989   | TV series    |
| **Radarr**| http://localhost:7878   | Movies       |
| **Lidarr**| http://localhost:8686   | Music        |
| **Bazarr**| http://localhost:6767   | Subtitles    |

---

## 🔧 Common Tasks

### ⏯️ Start/Stop the System

```powershell
# Start everything
cd C:\ARR-Stack
docker-compose up -d

# Stop everything
docker-compose down

# Restart a single service
docker-compose restart sonarr
```

### 📊 Check System Status

```powershell
cd C:\ARR-Stack
.\scripts\2_Manual_Control\status.ps1
```

### 💾 Manual Backup

```powershell
cd C:\ARR-Stack
.\scripts\1_Daily_Operations\backup-arr-stack-auto.ps1
```

### 🔄 Update All Services

```powershell
cd C:\ARR-Stack
docker-compose pull
docker-compose up -d
```

---

## 🛠️ Troubleshooting

### 🚨 VPN Not Working

**Problem**: Downloads not starting, or external IP shows your real IP

**Solution**:
1. Check Mullvad login in `.env` file
2. Restart VPN container:
   ```powershell
   docker-compose restart gluetun
   ```

### 🔌 Service Cannot Connect

**Problem**: Sonarr/Radarr cannot reach Transmission

**Solution**:
1. Check all services are running: `docker ps`
2. Restart the problematic service:
   ```powershell
   docker-compose restart sonarr
   ```

### 🚪 Port Conflicts

**Problem**: Service won't start due to port in use

**Solution**:
1. Find what is using the port: `netstat -an | findstr :9091`
2. Stop the conflicting program
3. Restart the service

---

## 📱 Shortcuts to All Services

### 🌐 Web Access

| Service | URL | Login |
|---------|-----|-------|
| 🎬 **Overseerr** | http://localhost:5055 | Create on first visit |
| 📥 **Transmission** | http://localhost:9091 | From .env file |
| 📺 **Sonarr** | http://localhost:8989 | None |
| 🎞️ **Radarr** | http://localhost:7878 | None |
| 🎵 **Lidarr** | http://localhost:8686 | None |
| 💬 **Bazarr** | http://localhost:6767 | None |
| 🔍 **Prowlarr** | http://localhost:9696 | None |
| ⚙️ **Tdarr** | http://localhost:8265 | None |
| 🐳 **Portainer** | https://localhost:9443 | Create on first visit |

### 📁 Important Folders

- **Media Library**: `C:\ARR-Stack\data\media\`
- **Downloads**: `C:\ARR-Stack\data\torrents\`
- **Backups**: `C:\ARR-Stack\backups\`
- **Scripts**: `C:\ARR-Stack\scripts\`

---

## 🔒 Security

### ✅ Check VPN Status

```powershell
# Check external IP (should not be your real IP)
docker exec transmission wget -qO- http://httpbin.org/ip
```

### 🔑 Change Passwords

Edit `.env` file and restart services:
```powershell
notepad C:\ARR-Stack\.env
docker-compose restart
```

---

## 📞 Get Help

### 🔍 Debugging

```powershell
# View logs for a service
docker-compose logs sonarr

# View live logs
docker-compose logs -f transmission

# Check container status
docker ps
```

### 🆘 Support

- **Log files**: Always check logs first
- **Community**: Reddit r/sonarr, r/radarr
- **Documentation**: See INSTALLATION_GUIDE.md for details

---

## ⚡ Pro Tips

1. **Bookmark** all service URLs in your browser
2. **Check status** daily with the status script
3. **Backup runs automatically** every night at 11:00 PM
4. **Mobile access**: Use your computer's IP instead of localhost
5. **Quality profiles**: Customize in each *arr service to your preferences

---

**🎉 Enjoy your enterprise media server system!**

*For advanced settings and troubleshooting, see the full INSTALLATION_GUIDE.md*
