#!/bin/bash

# Update Cloudflare Tunnel with New Token
# Quick fix script to update tunnel credentials

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
echo "Update Cloudflare Tunnel"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# New tunnel token
NEW_TOKEN="eyJhIjoiZThkZGNmOTA3Y2YwY2YxODk0NzkyZDNmNTEwNzlmOGEiLCJ0IjoiNTczZjRhOWYtZjBhYS00YmNlLThiNzgtYTU0ZWJhMTIwNWQ3IiwicyI6IllXWmtZMlExTXpndFpEUTFNUzAwTkdJeExUZ3pNR010WVdWaE5XWXpabVV5TVRreCJ9"

print_status "Parsing new tunnel token..."

# Decode the token (simple base64 format)
DECODED=$(echo "$NEW_TOKEN" | base64 -d 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Failed to decode token"
    exit 1
fi

# Extract tunnel information
TUNNEL_ID=$(echo "$DECODED" | jq -r '.t')
ACCOUNT_TAG=$(echo "$DECODED" | jq -r '.a')
TUNNEL_SECRET=$(echo "$DECODED" | jq -r '.s')

print_success "Tunnel ID: $TUNNEL_ID"
print_success "Account Tag: $ACCOUNT_TAG"

# Stop cloudflared service
print_status "Stopping cloudflared service..."
systemctl stop cloudflared

# Backup old credentials
if [ -f /etc/cloudflared/credentials.json ]; then
    print_status "Backing up old credentials..."
    cp /etc/cloudflared/credentials.json /etc/cloudflared/credentials.json.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create new credentials file
print_status "Creating new credentials file..."
cat > /etc/cloudflared/credentials.json << CREDS_FILE
{
  "AccountTag": "$ACCOUNT_TAG",
  "TunnelID": "$TUNNEL_ID",
  "TunnelSecret": "$TUNNEL_SECRET"
}
CREDS_FILE

chmod 600 /etc/cloudflared/credentials.json

# Update config file with new tunnel ID
print_status "Updating config file..."
if [ -f /etc/cloudflared/config.yml ]; then
    # Backup config
    cp /etc/cloudflared/config.yml /etc/cloudflared/config.yml.backup.$(date +%Y%m%d_%H%M%S)
    
    # Update tunnel ID in config
    sed -i "s/tunnel: .*/tunnel: $TUNNEL_ID/" /etc/cloudflared/config.yml
    
    print_success "Config updated"
    echo ""
    echo "Current config:"
    cat /etc/cloudflared/config.yml
else
    print_error "Config file not found at /etc/cloudflared/config.yml"
    exit 1
fi

# Start cloudflared service
print_status "Starting cloudflared service..."
systemctl start cloudflared

# Wait for service to start
sleep 5

# Check service status
if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared service is running"
else
    print_error "Cloudflared service failed to start"
    echo ""
    echo "Check logs with: sudo journalctl -u cloudflared.service -n 50"
    exit 1
fi

# Show recent logs
print_status "Recent logs:"
journalctl -u cloudflared.service -n 20 --no-pager

echo ""
print_success "Tunnel updated successfully!"
echo ""
echo "Your tunnel should now be accessible."
echo "Check status with: sudo systemctl status cloudflared"