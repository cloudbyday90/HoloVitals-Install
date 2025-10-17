# 🚀 UPDATED FIX SCRIPT - RUN THIS ONE

## ⚠️ Important: Use v2 Script

The original script had an issue with the directory path. **Use this updated version instead:**

## 📥 Download and Run

```bash
# Download the v2 script (fixed version)
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-holovitals-route-manifest-v2.sh

# Make it executable
chmod +x fix-holovitals-route-manifest-v2.sh

# Run it
sudo ./fix-holovitals-route-manifest-v2.sh
```

## ✨ What's Fixed in v2

### 1. **Auto-Detects Your Application Directory**
   - ✅ Finds app in `/home/holovitalsdev` (your actual location)
   - ✅ Also checks `/opt/HoloVitals` as fallback
   - ✅ Shows clear error if neither exists

### 2. **Fixes Cloudflare Tunnel Port to 3000**
   - ✅ Automatically updates `/etc/cloudflared/config.yml`
   - ✅ Changes any port back to 3000
   - ✅ Backs up config before changes
   - ✅ Restarts cloudflared service

### 3. **Better Error Handling**
   - ✅ Retries npm install if it fails
   - ✅ Cleans npm cache automatically
   - ✅ Provides manual steps if needed

## 🎯 What This Script Does

1. **Finds your app** - Auto-detects `/home/holovitalsdev`
2. **Stops service** - Safely stops HoloVitals
3. **Backs up build** - Saves your current `.next` directory
4. **Clears cache** - Removes corrupted build files
5. **Reinstalls deps** - Fresh `npm install`
6. **Rebuilds app** - Complete Next.js build
7. **Verifies build** - Checks everything is correct
8. **Fixes Cloudflare** - Updates config to port 3000
9. **Starts services** - Restarts both HoloVitals and Cloudflared
10. **Tests everything** - Verifies it's working

## ✅ Expected Success Output

```
========================================
0. LOCATING APPLICATION DIRECTORY
========================================
✓ Found application at: /home/holovitalsdev
✓ Changed to directory: /home/holovitalsdev

========================================
1. STOPPING HOLOVITALS SERVICE
========================================
✓ Service stopped

========================================
2. BACKING UP CURRENT BUILD
========================================
✓ Backed up .next to .next.backup_20251017_183000

========================================
5. REINSTALLING DEPENDENCIES
========================================
✓ Dependencies installed successfully

========================================
6. REBUILDING APPLICATION
========================================
✓ Build completed successfully

========================================
9. FIXING CLOUDFLARE TUNNEL CONFIGURATION
========================================
✓ Cloudflared config found
Current port in config: 3001
Updating to port 3000...
✓ Updated cloudflared config to use port 3000

========================================
10. STARTING HOLOVITALS SERVICE
========================================
✓ HoloVitals service started successfully

========================================
11. TESTING APPLICATION
========================================
HTTP Status Code: 200
✓ Application is responding correctly!

========================================
12. RESTARTING CLOUDFLARED
========================================
✓ Cloudflared restarted successfully

========================================
SUMMARY
========================================
Service Status:
  HoloVitals: active
  Cloudflared: active

✓ All services are running!

Your HoloVitals application should now be accessible at:
  - Local: http://localhost:3000
  - Domain: https://alpha.holovitals.net
```

## 🔍 After Running the Script

### Test Your Application

```bash
# Test locally
curl http://localhost:3000

# Test via domain
curl https://alpha.holovitals.net

# Check service status
sudo systemctl status holovitals
sudo systemctl status cloudflared
```

### View Logs (if needed)

```bash
# HoloVitals logs
journalctl -u holovitals.service -n 50

# Cloudflared logs
journalctl -u cloudflared.service -n 50
```

## 🆘 If It Still Fails

If the script fails, it will show you:
1. **Exactly where it failed** (which step)
2. **The error message** (what went wrong)
3. **Manual steps to try** (how to fix it yourself)

Save the output and share it:
```bash
sudo ./fix-holovitals-route-manifest-v2.sh > fix-output.txt 2>&1
```

## 📊 What Was Wrong

From your error screenshot:
- ❌ Script tried to `cd /opt/HoloVitals` (doesn't exist)
- ✅ Your app is actually in `/home/holovitalsdev`
- ❌ Cloudflared was on port 3001
- ✅ Should be on port 3000

**v2 script fixes all of these issues!**

## 🎯 Key Points

1. **Use the v2 script** - It has the fixes you need
2. **It will find your app** - Auto-detects `/home/holovitalsdev`
3. **It will fix the port** - Updates Cloudflare to 3000
4. **It will rebuild everything** - Fresh, clean build
5. **It will test everything** - Verifies it's working

---

**Download URL:** https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-holovitals-route-manifest-v2.sh

**Repository:** https://github.com/cloudbyday90/HoloVitals-Install

**Pull Request #13:** Merged ✓