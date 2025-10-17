#!/bin/bash

# Fix Corrupted Cloudflare Credentials
# Recreates credentials file from your tunnel token

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

echo "=================================="
echo "Fix Corrupted Cloudflare Credentials"
echo "=================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Your tunnel token
TUNNEL_TOKEN="eyJhIjoiZThkZGNmOTA3Y2YwY2YxODk0NzkyZDNmNTEwNzlmOGEiLCJ0IjoiNTczZjRhOWYtZjBhYS00YmNlLThiNzgtYTU0ZWJhMTIwNWQ3IiwicyI6IllXWmtZMlExTXpndFpEUTFNUzAwTkdJeExUZ3pNR010WVdWaE5XWXpabVV5TVRreCJ9"

print_status "Stopping cloudflared service..."
systemctl stop cloudflared

print_status "Backing up corrupted credentials..."
if [ -f /etc/cloudflared/credentials.json ]; then
    cp /etc/cloudflared/credentials.json /etc/cloudflared/credentials.json.corrupted_$(date +%Y%m%d_%H%M%S)
    print_success "Corrupted file backed up"
fi

print_status "Parsing tunnel token..."
DECODED=$(echo "$TUNNEL_TOKEN" | base64 -d 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Failed to decode token"
    exit 1
fi

TUNNEL_ID=$(echo "$DECODED" | jq -r '.t')
ACCOUNT_TAG=$(echo "$DECODED" | jq -r '.a')
TUNNEL_SECRET=$(echo "$DECODED" | jq -r '.s')

print_success "Tunnel ID: $TUNNEL_ID"
print_success "Account Tag: $ACCOUNT_TAG"

print_status "Creating FRESH credentials file..."
cat > /etc/cloudflared/credentials.json << EOF
{
  "AccountTag": "$ACCOUNT_TAG",
  "TunnelID": "$TUNNEL_ID",
  "TunnelSecret": "$TUNNEL_SECRET"
}
EOF

chmod 600 /etc/cloudflared/credentials.json

print_success "Fresh credentials created"

print_status "Validating credentials file..."
if jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
    print_success "Credentials file is valid JSON"
else
    print_error "Credentials file is STILL invalid"
    exit 1
fi

print_status "Updating config file with correct tunnel ID..."
if [ -f /etc/cloudflared/config.yml ]; then
    # Backup config
    cp /etc/cloudflared/config.yml /etc/cloudflared/config.yml.backup_$(date +%Y%m%d_%H%M%S)
    
    # Update tunnel ID
    sed -i "s/^tunnel: .*/tunnel: $TUNNEL_ID/" /etc/cloudflared/config.yml
    
    print_success "Config updated"
    echo ""
    echo "Current config:"
    cat /etc/cloudflared/config.yml
else
    print_error "Config file not found"
    exit 1
fi

print_status "Starting cloudflared service..."
systemctl start cloudflared

sleep 5

if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared is running"
else
    print_error "Cloudflared failed to start"
    echo ""
    echo "Check logs:"
    journalctl -u cloudflared.service -n 30 --no-pager
    exit 1
fi

echo ""
print_status "Recent logs:"
journalctl -u cloudflared.service -n 20 --no-pager

echo ""
print_success "Credentials fixed!"
echo ""
echo "Wait 30-60 seconds for tunnel to fully connect, then test:"
echo "  curl https://alpha.holovitals.net"
echo ""
echo "Check status:"
echo "  sudo systemctl status cloudflared"
echo "  sudo journalctl -u cloudflared.service -f"