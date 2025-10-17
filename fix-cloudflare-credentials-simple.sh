#!/bin/bash

# Fix Cloudflare Credentials - Simple Base64 Format
# This handles tokens that are simple base64-encoded JSON (not JWT format)

set -e

echo "=========================================="
echo "Cloudflare Tunnel Credentials Fix"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get token from command line or prompt
if [ -n "$1" ]; then
    CLOUDFLARE_TOKEN="$1"
else
    echo "Please enter your Cloudflare tunnel token:"
    read -p "Token: " CLOUDFLARE_TOKEN
fi

if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo -e "${RED}Error: Token is required${NC}"
    exit 1
fi

echo ""
echo "Parsing token..."

# Check if it's a JWT (has dots) or simple base64
if [[ "$CLOUDFLARE_TOKEN" == *.*.* ]]; then
    echo "Detected JWT format (3 parts)"
    # Extract payload (second part)
    IFS='.' read -ra JWT_PARTS <<< "$CLOUDFLARE_TOKEN"
    PAYLOAD_B64="${JWT_PARTS[1]}"
else
    echo "Detected simple base64 format"
    PAYLOAD_B64="$CLOUDFLARE_TOKEN"
fi

# Decode base64
PAYLOAD=$(echo "$PAYLOAD_B64" | base64 -d 2>/dev/null)

if [ -z "$PAYLOAD" ]; then
    echo -e "${RED}Error: Failed to decode token${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Successfully decoded token${NC}"
echo ""

# Install jq if needed
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    sudo apt-get update -qq
    sudo apt-get install -y jq
fi

# Extract fields
ACCOUNT_TAG=$(echo "$PAYLOAD" | jq -r '.a // empty')
TUNNEL_ID=$(echo "$PAYLOAD" | jq -r '.t // empty')
TUNNEL_SECRET_B64=$(echo "$PAYLOAD" | jq -r '.s // empty')

if [ -z "$ACCOUNT_TAG" ] || [ -z "$TUNNEL_ID" ] || [ -z "$TUNNEL_SECRET_B64" ]; then
    echo -e "${RED}Error: Failed to extract required fields${NC}"
    echo "Payload:"
    echo "$PAYLOAD" | jq '.'
    exit 1
fi

# The secret might be base64-encoded again, decode it
TUNNEL_SECRET=$(echo "$TUNNEL_SECRET_B64" | base64 -d 2>/dev/null || echo "$TUNNEL_SECRET_B64")

echo -e "${GREEN}✓ Successfully extracted credentials:${NC}"
echo "  AccountTag: ${ACCOUNT_TAG}"
echo "  TunnelID: ${TUNNEL_ID}"
echo "  TunnelSecret: ${TUNNEL_SECRET:0:20}..."
echo ""

# Create credentials directory
CREDS_DIR="/etc/cloudflared"
CREDS_FILE="$CREDS_DIR/credentials.json"

echo "Creating credentials file..."
sudo mkdir -p "$CREDS_DIR"

# Create properly formatted JSON
# Note: TunnelSecret should be the base64-encoded value
sudo tee "$CREDS_FILE" > /dev/null <<EOF
{
  "AccountTag": "$ACCOUNT_TAG",
  "TunnelSecret": "$TUNNEL_SECRET_B64",
  "TunnelID": "$TUNNEL_ID"
}
EOF

echo -e "${GREEN}✓ Created credentials file at $CREDS_FILE${NC}"
echo ""

# Validate JSON
echo "Validating credentials file..."
if sudo jq empty "$CREDS_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Credentials file is valid JSON${NC}"
else
    echo -e "${RED}Error: Created credentials file is not valid JSON${NC}"
    exit 1
fi

echo ""
echo "File contents:"
sudo jq '.' "$CREDS_FILE"
echo ""

# Set proper permissions
sudo chmod 600 "$CREDS_FILE"
echo -e "${GREEN}✓ Set proper permissions (600)${NC}"
echo ""

# Restart cloudflared service
echo "Restarting Cloudflare tunnel service..."
sudo systemctl stop cloudflared.service 2>/dev/null || true
sleep 2
sudo systemctl start cloudflared.service

echo -e "${GREEN}✓ Service restarted${NC}"
echo ""

# Wait for service to start
echo "Waiting for service to initialize..."
sleep 5

# Check service status
echo "Checking service status..."
if sudo systemctl is-active --quiet cloudflared.service; then
    echo -e "${GREEN}✓ Cloudflare tunnel is running!${NC}"
    echo ""
    sudo systemctl status cloudflared.service --no-pager -l | head -20
else
    echo -e "${RED}✗ Cloudflare tunnel failed to start${NC}"
    echo ""
    echo "Recent logs:"
    sudo journalctl -u cloudflared.service -n 30 --no-pager
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Credentials fix completed successfully!${NC}"
echo "=========================================="
echo ""