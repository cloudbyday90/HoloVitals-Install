# HoloVitals Installer

Public installer for the HoloVitals application.

## 🚀 One-Command Installation

```bash
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/install.sh && chmod +x install.sh && ./install.sh
```

**That's it!** The script will guide you through the rest.

## 🔑 What You Need

- **GitHub Personal Access Token** with `repo` scope
- Get it at: https://github.com/settings/tokens
  1. Click "Generate new token (classic)"
  2. Name: `HoloVitals`
  3. Check: ✅ **repo** (Full control of private repositories)
  4. Generate and copy the token

## 🐧 Supported Systems

- ✅ Ubuntu 20.04 LTS
- ✅ Ubuntu 22.04 LTS
- ✅ Ubuntu 24.04 LTS (with automatic repository fix)

## 📋 What It Does

1. ✅ Asks for your GitHub Personal Access Token
2. ✅ Fixes Ubuntu 24.04 repository issues automatically
3. ✅ Installs prerequisites (git, jq)
4. ✅ Clones the private HoloVitals repository
5. ✅ Launches the modular installer

## 🎯 Installation Modes

After the installer runs, you can choose:

### Development Mode (6 phases)
- Quick local testing
- No database or authentication
- Access via http://localhost:3000

### Secure Development Mode (13 phases)
- PostgreSQL database
- Admin authentication
- Cloudflare Tunnel for HTTPS
- Systemd services
- Firewall configuration

### Production Mode (14 phases)
- All Secure-Dev features
- NGINX reverse proxy
- Full security hardening
- Automated backups

## ⏱️ Installation Time

- Development: ~5 minutes
- Secure-Dev: ~15 minutes
- Production: ~20 minutes

## 🛠️ Recovery &amp; Fix Scripts

If you encounter issues during installation, we have dedicated fix scripts:

### Phase 03: Database Connection Issues
```bash
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-database-connection.sh
chmod +x fix-database-connection.sh
./fix-database-connection.sh
```

### Phase 07/08: Migration &amp; Admin User Issues
```bash
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-phase-07-migration.sh
chmod +x fix-phase-07-migration.sh
./fix-phase-07-migration.sh
```

### Phase 11: Cloudflare Tunnel Issues
```bash
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-cloudflare-tunnel.sh
chmod +x fix-cloudflare-tunnel.sh
./fix-cloudflare-tunnel.sh
```

### Phase 11: Cloudflare Credentials Format Issues
If you see "invalid JSON" errors in Cloudflare tunnel logs:
```bash
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-cloudflare-credentials.sh
chmod +x fix-cloudflare-credentials.sh
./fix-cloudflare-credentials.sh
```
📖 [Detailed Guide](CLOUDFLARE_CREDENTIALS_FIX.md)

### General Diagnostics
```bash
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/debug-installer.sh
chmod +x debug-installer.sh
./debug-installer.sh
```

## ❓ Troubleshooting

### "Failed to download repository"

**Check:**
1. Your GitHub PAT is valid (not expired)
2. Your PAT has `repo` scope selected
3. You have access to the cloudbyday90/HoloVitals repository

### Ubuntu 24.04 repository errors

The installer automatically fixes these. If issues persist:
```bash
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*
sudo apt-get update
```

### "Permission denied"

Make sure the script is executable:
```bash
chmod +x install.sh
```

### Cloudflare Tunnel "Invalid JSON" Error

This occurs when the credentials file is not properly formatted. Use the dedicated fix:
```bash
./fix-cloudflare-credentials.sh
```
See [CLOUDFLARE_CREDENTIALS_FIX.md](CLOUDFLARE_CREDENTIALS_FIX.md) for details.

## 🔐 Security Notes

- Your GitHub PAT is only used to clone the repository
- The PAT is not stored anywhere
- Keep your PAT secure and don't share it
- Rotate your PAT regularly (every 90 days recommended)

## 📚 Documentation

For detailed documentation, see the main HoloVitals repository.

---

**Simple. Public. Works.**