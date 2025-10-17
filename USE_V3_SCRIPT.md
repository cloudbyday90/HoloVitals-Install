# 🚀 USE THIS SCRIPT - v3 with Auto Package Installation

## ⚠️ Important Update

The v3 script now **automatically fixes missing packages and scripts** in your package.json!

## 📥 Download and Run v3

```bash
# Download the v3 script
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-holovitals-route-manifest-v3.sh

# Make it executable
chmod +x fix-holovitals-route-manifest-v3.sh

# Run it
sudo ./fix-holovitals-route-manifest-v3.sh
```

## 🆕 What's New in v3

### Fixes the "Unknown command: build" Error

Your screenshot showed:
```
npm run build
Unknown command: "build"
```

**v3 automatically fixes this by:**

1. ✅ **Checking package.json** for build/start/dev scripts
2. ✅ **Adding missing scripts** if they don't exist
3. ✅ **Checking for Next.js** package
4. ✅ **Installing Next.js** if missing
5. ✅ **Checking for React** packages
6. ✅ **Installing React** if missing
7. ✅ **Verifying installation** before building
8. ✅ **Using fallback build** (npx next build) if needed

### What It Will Add to Your package.json

If missing, the script adds:

```json
{
  "scripts": {
    "build": "next build",
    "start": "next start",
    "dev": "next dev"
  },
  "dependencies": {
    "next": "latest",
    "react": "latest",
    "react-dom": "latest"
  }
}
```

## 🎯 Complete Feature List

1. ✅ Auto-detects app directory (`/home/holovitalsdev`)
2. ✅ **Checks and adds missing scripts**
3. ✅ **Checks and installs missing packages**
4. ✅ Stops service
5. ✅ Backs up build
6. ✅ Clears cache
7. ✅ Installs/updates dependencies
8. ✅ **Verifies Next.js is installed**
9. ✅ Rebuilds application (with fallback)
10. ✅ Verifies build output
11. ✅ Checks environment
12. ✅ **Fixes Cloudflare port to 3000**
13. ✅ Starts services
14. ✅ Tests application
15. ✅ **Restarts Cloudflared**

## ✅ Expected Output

```
========================================
1. CHECKING PACKAGE.JSON CONFIGURATION
========================================
✓ Build script found in package.json
✓ Start script found in package.json
✓ Dev script found in package.json

========================================
2. CHECKING REQUIRED PACKAGES
========================================
✓ Next.js found in package.json: 15.5.4
✓ React found in package.json

========================================
6. INSTALLING/UPDATING DEPENDENCIES
========================================
✓ Dependencies installed successfully

========================================
7. VERIFYING NEXT.JS INSTALLATION
========================================
✓ Next.js installed in node_modules
✓ Installed Next.js version: 15.5.4

========================================
8. REBUILDING APPLICATION
========================================
✓ Build completed successfully

========================================
11. FIXING CLOUDFLARE TUNNEL CONFIGURATION
========================================
✓ Cloudflared config found
Current port in config: 3001
Updating to port 3000...
✓ Updated cloudflared config to use port 3000

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

## 🔧 What If It Still Fails?

The script has multiple fallback strategies:

1. **First try:** `npm install --legacy-peer-deps`
2. **If fails:** Clean cache and retry
3. **If still fails:** Install core packages individually
4. **Build fallback:** Use `npx next build` if `npm run build` fails

## 📊 Comparison

| Issue | v2 | v3 |
|-------|----|----|
| Auto-detect directory | ✅ | ✅ |
| Fix Cloudflare port | ✅ | ✅ |
| **Check package.json scripts** | ❌ | ✅ |
| **Add missing scripts** | ❌ | ✅ |
| **Check required packages** | ❌ | ✅ |
| **Install missing packages** | ❌ | ✅ |
| **Verify Next.js** | ❌ | ✅ |
| **Fallback build** | ❌ | ✅ |

## 🎯 Bottom Line

**v3 is a complete solution** that handles:
- ✅ Missing build scripts
- ✅ Missing packages
- ✅ Failed installations
- ✅ Build errors
- ✅ Port configuration
- ✅ Service management

Just run it and it will fix everything automatically!

---

**Download:** https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-holovitals-route-manifest-v3.sh

**Repository:** https://github.com/cloudbyday90/HoloVitals-Install

**Pull Request #14:** Merged ✓