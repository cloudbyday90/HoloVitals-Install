#!/bin/bash

# Fix Cloudflare Tunnel Credentials
# This script properly parses the JWT token and creates valid credentials.json

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

# Find HoloVitals installation
HOLOVITALS_DIR="$HOME/HoloVitals"
if [ ! -d "$HOLOVITALS_DIR" ]; then
    echo -e "${RED}Error: HoloVitals directory not found at $HOLOVITALS_DIR${NC}"
    exit 1
fi

CONFIG_FILE="$HOLOVITALS_DIR/scripts/installer_config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Configuration file not found at $CONFIG_FILE${NC}"
    exit 1
fi

echo "✓ Found HoloVitals installation"
echo ""

# Load configuration
source "$CONFIG_FILE"

# Check if cloudflare_token exists
if [ -z "$cloudflare_token" ]; then
    echo -e "${RED}Error: No Cloudflare token found in configuration${NC}"
    echo "Please run the installer Phase 11 first to set up Cloudflare tunnel"
    exit 1
fi

echo "✓ Found Cloudflare token in configuration"
echo ""

# Function to decode base64 URL-safe
decode_base64_url() {
    local input="$1"
    # Add padding if needed
    local padded="$input"
    case $((${#input} % 4)) in
        2) padded="${input}==" ;;
        3) padded="${input}=" ;;
    esac
    # Replace URL-safe characters
    padded=$(echo "$padded" | tr '_-' '/+')
    # Decode
    echo "$padded" | base64 -d 2>/dev/null
}

# Parse JWT token
echo "Parsing JWT token..."
IFS='.' read -ra JWT_PARTS <<< "$cloudflare_token"

if [ ${#JWT_PARTS[@]} -ne 3 ]; then
    echo -e "${RED}Error: Invalid JWT token format${NC}"
    echo "Expected 3 parts separated by dots, got ${#JWT_PARTS[@]}"
    exit 1
fi

# Decode the payload (second part)
PAYLOAD=$(decode_base64_url "${JWT_PARTS[1]}")

if [ -z "$PAYLOAD" ]; then
    echo -e "${RED}Error: Failed to decode JWT payload${NC}"
    exit 1
fi

echo "✓ Successfully decoded JWT token"
echo ""

# Extract fields using jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq for JSON parsing...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y jq
fi

ACCOUNT_TAG=$(echo "$PAYLOAD" | jq -r '.a // empty')
TUNNEL_SECRET=$(echo "$PAYLOAD" | jq -r '.s // empty')
TUNNEL_ID=$(echo "$PAYLOAD" | jq -r '.t // empty')

# Validate extracted fields
if [ -z "$ACCOUNT_TAG" ] || [ -z "$TUNNEL_SECRET" ] || [ -z "$TUNNEL_ID" ]; then
    echo -e "${RED}Error: Failed to extract required fields from JWT token${NC}"
    echo "Payload content:"
    echo "$PAYLOAD" | jq '.'
    echo ""
    echo "Extracted values:"
    echo "  AccountTag: ${ACCOUNT_TAG:-<empty>}"
    echo "  TunnelSecret: ${TUNNEL_SECRET:-<empty>}"
    echo "  TunnelID: ${TUNNEL_ID:-<empty>}"
    exit 1
fi

echo "✓ Successfully extracted credentials:"
echo "  AccountTag: ${ACCOUNT_TAG:0:20}..."
echo "  TunnelSecret: ${TUNNEL_SECRET:0:20}..."
echo "  TunnelID: $TUNNEL_ID"
echo ""

# Create credentials directory
CREDS_DIR="/etc/cloudflared"
CREDS_FILE="$CREDS_DIR/credentials.json"

echo "Creating credentials file..."
sudo mkdir -p "$CREDS_DIR"

# Create properly formatted JSON
sudo tee "$CREDS_FILE" > /dev/null <<EOF
{
  "AccountTag": "$ACCOUNT_TAG",
  "TunnelSecret": "$TUNNEL_SECRET",
  "TunnelID": "$TUNNEL_ID"
}
EOF

echo "✓ Created credentials file at $CREDS_FILE"
echo ""

# Validate JSON
echo "Validating credentials file..."
if sudo jq empty "$CREDS_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓ Credentials file is valid JSON${NC}"
else
    echo -e "${RED}Error: Created credentials file is not valid JSON${NC}"
    echo "File contents:"
    sudo cat "$CREDS_FILE"
    exit 1
fi

echo ""
echo "File contents:"
sudo jq '.' "$CREDS_FILE"
echo ""

# Set proper permissions
sudo chmod 600 "$CREDS_FILE"
echo "✓ Set proper permissions (600)"
echo ""

# Restart cloudflared service
echo "Restarting Cloudflare tunnel service..."
sudo systemctl stop cloudflared.service 2>/dev/null || true
sleep 2
sudo systemctl start cloudflared.service

echo "✓ Service restarted"
echo ""

# Wait a moment for service to start
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
echo "Your tunnel should now be accessible at:"
echo "  https://$domain_name"
echo ""