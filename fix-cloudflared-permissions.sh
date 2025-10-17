#!/bin/bash

# Fix Cloudflared Permissions and Network Issues
# Fixes GID/ping_group_range and tunnel serving errors

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "=================================="
echo "Fix Cloudflared Permissions"
echo "=================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# 1. Fix ping_group_range
print_status "Fixing ping_group_range..."
echo "net.ipv4.ping_group_range = 0 2147483647" > /etc/sysctl.d/99-cloudflared.conf
sysctl -p /etc/sysctl.d/99-cloudflared.conf
print_success "ping_group_range configured"

# 2. Stop cloudflared
print_status "Stopping cloudflared..."
systemctl stop cloudflared
sleep 2

# 3. Check application is running
print_status "Checking application status..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    print_success "Application is responding on port 3000"
else
    print_error "Application is NOT responding on port 3000"
    print_status "Checking HoloVitals service..."
    systemctl status holovitals --no-pager -l | tail -20
    echo ""
    print_warning "Fix application first, then re-run this script"
    exit 1
fi

# 4. Verify credentials and config
print_status "Verifying credentials..."
if [ -f /etc/cloudflared/credentials.json ]; then
    if jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
        print_success "Credentials file is valid JSON"
        CREDS_TUNNEL_ID=$(jq -r '.TunnelID' /etc/cloudflared/credentials.json)
        print_status "Credentials Tunnel ID: $CREDS_TUNNEL_ID"
    else
        print_error "Credentials file is invalid JSON"
        print_status "Run fix-corrupted-credentials.sh first"
        exit 1
    fi
else
    print_error "Credentials file not found"
    exit 1
fi

print_status "Verifying config..."
if [ -f /etc/cloudflared/config.yml ]; then
    CONFIG_TUNNEL_ID=$(grep "^tunnel:" /etc/cloudflared/config.yml | awk '{print $2}')
    print_status "Config Tunnel ID: $CONFIG_TUNNEL_ID"
    
    if [ "$CREDS_TUNNEL_ID" != "$CONFIG_TUNNEL_ID" ]; then
        print_error "Tunnel ID mismatch!"
        print_status "Fixing config..."
        sed -i "s/^tunnel: .*/tunnel: $CREDS_TUNNEL_ID/" /etc/cloudflared/config.yml
        print_success "Config updated to match credentials"
    else
        print_success "Tunnel IDs match"
    fi
else
    print_error "Config file not found"
    exit 1
fi

# 5. Ensure config points to correct port
print_status "Verifying service URL..."
SERVICE_URL=$(grep "service: http" /etc/cloudflared/config.yml | head -1 | awk '{print $2}')
print_status "Current service URL: $SERVICE_URL"

if [ "$SERVICE_URL" != "http://localhost:3000" ]; then
    print_warning "Service URL is incorrect"
    print_status "Fixing service URL..."
    sed -i 's|service: http://localhost:[0-9]*|service: http://localhost:3000|g' /etc/cloudflared/config.yml
    print_success "Service URL updated to http://localhost:3000"
fi

# 6. Show final config
echo ""
print_status "Final configuration:"
cat /etc/cloudflared/config.yml

# 7. Restart cloudflared
echo ""
print_status "Starting cloudflared with fixed configuration..."
systemctl start cloudflared

sleep 5

if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared is running"
else
    print_error "Cloudflared failed to start"
    echo ""
    journalctl -u cloudflared.service -n 30 --no-pager
    exit 1
fi

# 8. Wait and check logs
print_status "Waiting for tunnel to connect (30 seconds)..."
sleep 30

echo ""
print_status "Recent logs:"
journalctl -u cloudflared.service -n 30 --no-pager | tail -20

# 9. Check for errors
echo ""
print_status "Checking for errors..."
if journalctl -u cloudflared.service -n 50 --no-pager | grep -i "error\|failed" | grep -v "ping_group"; then
    print_warning "Found errors in logs (see above)"
else
    print_success "No critical errors in recent logs"
fi

# 10. Test domain
echo ""
print_status "Testing domain connectivity..."
DOMAIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://alpha.holovitals.net 2>/dev/null || echo "000")
print_status "Domain HTTP Status: $DOMAIN_CODE"

if [ "$DOMAIN_CODE" = "200" ] || [ "$DOMAIN_CODE" = "301" ] || [ "$DOMAIN_CODE" = "302" ]; then
    print_success "Domain is accessible!"
    echo ""
    echo "✅ Your site is now working: https://alpha.holovitals.net"
elif [ "$DOMAIN_CODE" = "530" ] || [ "$DOMAIN_CODE" = "1033" ]; then
    print_warning "Still getting Error $DOMAIN_CODE"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Wait another 30-60 seconds for tunnel to fully connect"
    echo "2. Check tunnel status: sudo journalctl -u cloudflared.service -f"
    echo "3. Verify in Cloudflare dashboard that tunnel shows as 'Healthy'"
    echo "4. Check application: curl http://localhost:3000"
else
    print_warning "Domain returns HTTP $DOMAIN_CODE"
fi

echo ""
echo "=================================="
echo "Fix Complete"
echo "=================================="
echo ""
echo "Monitor tunnel status:"
echo "  sudo journalctl -u cloudflared.service -f"
echo ""
echo "Check application:"
echo "  curl http://localhost:3000"
echo ""
echo "Test domain:"
echo "  curl https://alpha.holovitals.net"