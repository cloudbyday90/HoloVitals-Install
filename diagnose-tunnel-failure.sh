#!/bin/bash

# Comprehensive Cloudflare Tunnel Diagnostics
# This script provides detailed information about tunnel failure

echo "=========================================="
echo "Cloudflare Tunnel Failure Diagnostics"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Collecting diagnostic information...${NC}"
echo ""

# 1. Check cloudflared service status
echo "=========================================="
echo "1. Cloudflared Service Status"
echo "=========================================="
if systemctl is-active --quiet cloudflared.service; then
    echo -e "${GREEN}✓ Service is running${NC}"
else
    echo -e "${RED}✗ Service is NOT running${NC}"
fi
echo ""
sudo systemctl status cloudflared.service --no-pager -l | head -20
echo ""

# 2. Check recent logs
echo "=========================================="
echo "2. Recent Service Logs (Last 50 lines)"
echo "=========================================="
sudo journalctl -u cloudflared.service -n 50 --no-pager
echo ""

# 3. Check credentials file
echo "=========================================="
echo "3. Credentials File Check"
echo "=========================================="
if [ -f /etc/cloudflared/credentials.json ]; then
    echo -e "${GREEN}✓ Credentials file exists${NC}"
    echo ""
    echo "File permissions:"
    ls -l /etc/cloudflared/credentials.json
    echo ""
    echo "File format validation:"
    if sudo jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
        echo -e "${GREEN}✓ Valid JSON format${NC}"
        echo ""
        echo "Credentials structure:"
        sudo jq 'keys' /etc/cloudflared/credentials.json
        echo ""
        echo "Tunnel ID from credentials:"
        sudo jq -r '.TunnelID' /etc/cloudflared/credentials.json
    else
        echo -e "${RED}✗ INVALID JSON FORMAT${NC}"
        echo ""
        echo "File contents (first 500 chars):"
        sudo head -c 500 /etc/cloudflared/credentials.json
        echo ""
    fi
else
    echo -e "${RED}✗ Credentials file NOT FOUND${NC}"
fi
echo ""

# 4. Check config file
echo "=========================================="
echo "4. Configuration File Check"
echo "=========================================="
if [ -f /etc/cloudflared/config.yml ]; then
    echo -e "${GREEN}✓ Config file exists${NC}"
    echo ""
    echo "Configuration:"
    sudo cat /etc/cloudflared/config.yml
else
    echo -e "${RED}✗ Config file NOT FOUND${NC}"
fi
echo ""

# 5. Check application on port 3000
echo "=========================================="
echo "5. Application Status (Port 3000)"
echo "=========================================="
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is responding on port 3000${NC}"
    echo ""
    echo "Response headers:"
    curl -I http://localhost:3000 2>/dev/null | head -10
else
    echo -e "${RED}✗ Application is NOT responding on port 3000${NC}"
    echo ""
    echo "Checking what's listening on port 3000:"
    sudo lsof -i :3000 || echo "Nothing listening on port 3000"
fi
echo ""

# 6. Check HoloVitals service
echo "=========================================="
echo "6. HoloVitals Application Service"
echo "=========================================="
if systemctl list-units --all | grep -q holovitals; then
    echo "HoloVitals service found:"
    sudo systemctl status holovitals.service --no-pager -l | head -20
else
    echo "No HoloVitals systemd service found"
    echo ""
    echo "Checking for PM2 processes:"
    if command -v pm2 &> /dev/null; then
        pm2 list
    else
        echo "PM2 not installed"
    fi
fi
echo ""

# 7. Check installer configuration
echo "=========================================="
echo "7. Installer Configuration"
echo "=========================================="
if [ -f ~/HoloVitals/scripts/installer_config.txt ]; then
    echo -e "${GREEN}✓ Installer config found${NC}"
    echo ""
    echo "Cloudflare configuration:"
    grep -E "(cloudflare_token|tunnel_id|domain_name)" ~/HoloVitals/scripts/installer_config.txt || echo "No Cloudflare config found"
else
    echo -e "${RED}✗ Installer config NOT FOUND${NC}"
fi
echo ""

# 8. Network connectivity
echo "=========================================="
echo "8. Network Connectivity"
echo "=========================================="
echo "Testing connection to Cloudflare:"
if ping -c 2 1.1.1.1 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Can reach Cloudflare DNS (1.1.1.1)${NC}"
else
    echo -e "${RED}✗ Cannot reach Cloudflare DNS${NC}"
fi
echo ""

# 9. Check for error patterns in logs
echo "=========================================="
echo "9. Error Analysis"
echo "=========================================="
echo "Checking for common error patterns..."
echo ""

if sudo journalctl -u cloudflared.service -n 100 --no-pager | grep -q "Authentication failed"; then
    echo -e "${RED}✗ FOUND: Authentication errors${NC}"
    echo "  → Token may be invalid or expired"
fi

if sudo journalctl -u cloudflared.service -n 100 --no-pager | grep -q "invalid JSON"; then
    echo -e "${RED}✗ FOUND: Invalid JSON errors${NC}"
    echo "  → Credentials file format is incorrect"
fi

if sudo journalctl -u cloudflared.service -n 100 --no-pager | grep -q "connection refused"; then
    echo -e "${RED}✗ FOUND: Connection refused errors${NC}"
    echo "  → Application on port 3000 is not running"
fi

if sudo journalctl -u cloudflared.service -n 100 --no-pager | grep -q "dial tcp.*3000.*connection refused"; then
    echo -e "${RED}✗ FOUND: Cannot connect to port 3000${NC}"
    echo "  → Application needs to be started"
fi

if sudo journalctl -u cloudflared.service -n 100 --no-pager | grep -q "Registered tunnel connection"; then
    echo -e "${GREEN}✓ FOUND: Successful tunnel registration${NC}"
    echo "  → Tunnel has connected successfully at some point"
fi

echo ""

# 10. Summary and recommendations
echo "=========================================="
echo "10. Summary & Recommendations"
echo "=========================================="
echo ""

# Determine the main issue
ISSUE_FOUND=false

if [ ! -f /etc/cloudflared/credentials.json ]; then
    echo -e "${RED}CRITICAL: Credentials file missing${NC}"
    echo "Fix: Run fix-cloudflare-credentials.sh"
    ISSUE_FOUND=true
elif ! sudo jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
    echo -e "${RED}CRITICAL: Credentials file has invalid JSON${NC}"
    echo "Fix: Run fix-cloudflare-credentials.sh"
    ISSUE_FOUND=true
fi

if ! systemctl is-active --quiet cloudflared.service; then
    echo -e "${RED}CRITICAL: Cloudflared service not running${NC}"
    echo "Fix: sudo systemctl start cloudflared"
    ISSUE_FOUND=true
fi

if ! curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${YELLOW}WARNING: Application not running on port 3000${NC}"
    echo "This is likely why the tunnel shows as 'down'"
    echo "Fix: Start the application"
    echo "  cd ~/HoloVitals/medical-analysis-platform"
    echo "  npm run dev"
    ISSUE_FOUND=true
fi

if [ "$ISSUE_FOUND" = false ]; then
    echo -e "${GREEN}No obvious issues found${NC}"
    echo "The tunnel may just need time to connect (30-60 seconds)"
    echo "Or check the Cloudflare dashboard for DNS/routing issues"
fi

echo ""
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Review the output above"
echo "2. Fix any CRITICAL issues first"
echo "3. Then fix WARNING issues"
echo "4. Wait 30-60 seconds after fixes"
echo "5. Check tunnel status again"
echo ""