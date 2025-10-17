# 🚀 Quick Start - HoloVitals v1.5.0.45

## For Fresh Installation

### Step 1: Download Installer

```bash
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals/main/scripts/install-v1.5.0.45.sh
chmod +x install-v1.5.0.45.sh
```

### Step 2: Run Installer

```bash
./install-v1.5.0.45.sh
```

### Step 3: Follow Prompts

1. **Select Mode:**
   - `dev` - Quick local development
   - `secure-dev` - Development with auth
   - `production` - Full production setup

2. **GitHub PAT (Optional):**
   - Enter your GitHub Personal Access Token
   - Or skip if repository is public

3. **Cloudflare (Production Only):**
   - Enter your Cloudflare Tunnel token
   - Enter your domain (e.g., alpha.holovitals.net)

### Step 4: Wait for Completion

The installer will:
- ✅ Clone repository
- ✅ Validate package.json (auto-fix if needed)
- ✅ Install dependencies (multiple strategies)
- ✅ Build application
- ✅ Verify build output
- ✅ Start services
- ✅ Validate port configuration
- ✅ Setup Cloudflare (if requested)
- ✅ Run final validation

### Step 5: Access Application

**Development:**
```bash
cd HoloVitals/medical-analysis-platform
npm run dev
# Access: http://localhost:3000
```

**Production:**
```bash
# Already running as service
# Access: http://localhost:3000
# Or: https://your-domain.com
```

## What's Different in v1.5.0.45?

### ✅ Automatic Fixes
- Missing build scripts → **Added automatically**
- Missing packages → **Installed automatically**
- Wrong directory → **Detected automatically**
- Port issues → **Validated automatically**

### ✅ Better Ordering
- Cloudflare setup **AFTER** app verification
- Health checks **BEFORE** Cloudflare
- Build verification **BEFORE** service start

### ✅ Universal Compatibility
- Works with **ANY username** (holovitalsdev, ubuntu, admin, etc.)
- Works with **ANY folder structure**
- **No hardcoded paths**

## Common Issues - Now Fixed!

### ❌ Old Issue: "Unknown command: build"
✅ **Fixed:** Installer adds build script automatically in Phase 6.5

### ❌ Old Issue: "package.json not found"
✅ **Fixed:** Dynamic directory detection in all phases

### ❌ Old Issue: "npm install fails"
✅ **Fixed:** Multiple installation strategies with fallback

### ❌ Old Issue: "Application not responding"
✅ **Fixed:** Port validation and health checks in Phase 12.5

### ❌ Old Issue: "Cloudflare tunnel fails"
✅ **Fixed:** Cloudflare setup after app verification in Phase 14

## Quick Commands

### Check Status
```bash
sudo systemctl status holovitals
sudo systemctl status cloudflared  # if configured
```

### View Logs
```bash
sudo journalctl -u holovitals.service -f
sudo journalctl -u cloudflared.service -f  # if configured
```

### Restart Services
```bash
sudo systemctl restart holovitals
sudo systemctl restart cloudflared  # if configured
```

### Check Port
```bash
sudo netstat -tulpn | grep 3000
curl http://localhost:3000
```

## Admin Credentials

Located at: `~/HoloVitals/ADMIN_CREDENTIALS.txt`

```bash
cat ~/HoloVitals/ADMIN_CREDENTIALS.txt
```

**Remember to change the password after first login!**

## Need Help?

### Check Installation Log
```bash
cat /var/log/holovitals-install.log
```

### Verify Package.json
```bash
cd ~/HoloVitals/medical-analysis-platform
cat package.json | jq '.scripts'
```

### Test Application
```bash
curl http://localhost:3000
```

### Check Build Output
```bash
ls -la ~/HoloVitals/medical-analysis-platform/.next/
cat ~/HoloVitals/medical-analysis-platform/.next/BUILD_ID
```

## Success Indicators

You should see:
- ✅ All phases complete without errors
- ✅ Service running: `sudo systemctl status holovitals`
- ✅ Port listening: `sudo netstat -tulpn | grep 3000`
- ✅ Application responds: `curl http://localhost:3000`
- ✅ Cloudflare connected (if configured)

## What Gets Installed

### System Packages
- Node.js 20
- PostgreSQL
- Redis
- NGINX (production)
- cloudflared (if Cloudflare configured)
- jq (JSON processor)

### Application
- HoloVitals repository
- All npm dependencies
- Built Next.js application
- Systemd service
- Admin user (secure-dev/production)

### Configuration
- .env.local with secure secrets
- Database with migrations
- NGINX reverse proxy (production)
- Cloudflare tunnel (if configured)
- Firewall rules (production)

## Repository Links

- **Private Repo:** https://github.com/cloudbyday90/HoloVitals
- **Public Repo (Fix Scripts):** https://github.com/cloudbyday90/HoloVitals-Install
- **Pull Request:** https://github.com/cloudbyday90/HoloVitals/pull/24

---

**Ready to install?** Just run the installer and follow the prompts!

```bash
./install-v1.5.0.45.sh
```