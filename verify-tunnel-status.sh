#!/bin/bash

# Verify Cloudflare Tunnel Status
# This script checks if the tunnel is actually working

echo "=========================================="
echo "Cloudflare Tunnel Status Verification"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if cloudflared service is running
echo "1. Checking cloudflared service..."
if systemctl is-active --quiet cloudflared.service; then
    echo -e "${GREEN}✓ Service is running${NC}"
else
    echo -e "${RED}✗ Service is not running${NC}"
    echo "Start it with: sudo systemctl start cloudflared"
    exit 1
fi

echo ""

# Check service status
echo "2. Service status:"
sudo systemctl status cloudflared.service --no-pager -l | head -15
echo ""

# Check recent logs for connection status
echo "3. Recent logs (last 20 lines):"
sudo journalctl -u cloudflared.service -n 20 --no-pager | tail -20
echo ""

# Check if application is running on port 3000
echo "4. Checking if application is running on port 3000..."
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is responding on port 3000${NC}"
else
    echo -e "${YELLOW}⚠ Application is not responding on port 3000${NC}"
    echo "The tunnel needs an application running on port 3000 to proxy to."
    echo "This is likely why the tunnel shows as 'not yet registered'."
    echo ""
    echo "Next steps:"
    echo "1. Continue with the installer to start the application"
    echo "2. Or manually start the application with: cd ~/HoloVitals/medical-analysis-platform && npm run dev"
fi

echo ""

# Check credentials file
echo "5. Checking credentials file format..."
if sudo jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
    echo -e "${GREEN}✓ Credentials file is valid JSON${NC}"
    echo "Credentials structure:"
    sudo jq 'keys' /etc/cloudflared/credentials.json
else
    echo -e "${RED}✗ Credentials file has invalid JSON${NC}"
    exit 1
fi

echo ""

# Check config file
echo "6. Checking tunnel configuration..."
if [ -f /etc/cloudflared/config.yml ]; then
    echo -e "${GREEN}✓ Config file exists${NC}"
    echo "Configuration:"
    sudo cat /etc/cloudflared/config.yml
else
    echo -e "${RED}✗ Config file not found${NC}"
    exit 1
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

# Check for specific log messages
if sudo journalctl -u cloudflared.service -n 50 --no-pager | grep -q "Registered tunnel connection"; then
    echo -e "${GREEN}✓ Tunnel is fully connected and registered!${NC}"
    echo ""
    echo "Your application should be accessible at your domain."
elif sudo journalctl -u cloudflared.service -n 50 --no-pager | grep -q "Connection.*registered"; then
    echo -e "${GREEN}✓ Tunnel connection is registered!${NC}"
    echo ""
    echo "Your application should be accessible at your domain."
elif sudo journalctl -u cloudflared.service -n 50 --no-pager | grep -q "ERR"; then
    echo -e "${RED}✗ Tunnel has errors${NC}"
    echo ""
    echo "Check the logs above for specific error messages."
else
    echo -e "${YELLOW}⚠ Tunnel is starting but not fully connected yet${NC}"
    echo ""
    echo "This is normal if:"
    echo "1. The application on port 3000 is not running yet"
    echo "2. The service just started (give it 30-60 seconds)"
    echo "3. DNS records are still propagating"
    echo ""
    echo "Wait a moment and run this script again."
fi

echo ""