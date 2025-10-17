#!/bin/bash

# Manual Cloudflare Credentials Fix
# This version prompts for the token if config file is not found

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

# Try to find HoloVitals installation
HOLOVITALS_DIR=""
if [ -d "$HOME/HoloVitals" ]; then
    HOLOVITALS_DIR="$HOME/HoloVitals"
elif [ -d "/home/holovitalsdev/HoloVitals" ]; then
    HOLOVITALS_DIR="/home/holovitalsdev/HoloVitals"
else
    # Search for it
    echo "Searching for HoloVitals installation..."
    FOUND=$(find ~ -maxdepth 3 -type d -name "HoloVitals" 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        HOLOVITALS_DIR="$FOUND"
    fi
fi

if [ -n "$HOLOVITALS_DIR" ]; then
    echo -e "${GREEN}✓ Found HoloVitals installation at: $HOLOVITALS_DIR${NC}"
    CONFIG_FILE="$HOLOVITALS_DIR/scripts/installer_config.txt"
else
    echo -e "${YELLOW}⚠ Could not find HoloVitals installation${NC}"
    CONFIG_FILE=""
fi

echo ""

# Try to load token from config
CLOUDFLARE_TOKEN=""
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ Found configuration file${NC}"
    source "$CONFIG_FILE"
    CLOUDFLARE_TOKEN="$cloudflare_token"
fi

# If no token found, prompt for it
if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo -e "${YELLOW}⚠ Could not find Cloudflare token in configuration${NC}"
    echo ""
    echo "Please enter your Cloudflare tunnel token:"
    echo "(It should start with 'eyJ' and be a long string)"
    echo ""
    read -p "Token: " CLOUDFLARE_TOKEN
    
    if [ -z "$CLOUDFLARE_TOKEN" ]; then
        echo -e "${RED}Error: Token is required${NC}"
        exit 1
    fi
fi

echo ""
echo "Parsing JWT token..."

# Function to decode base64 URL-safe
decode_base64_url() {
    local input="$1"
    local padded="$input"
    case $((${#input} % 4)) in
        2) padded="${input}==" ;;
        3) padded="${input}=" ;;
    esac
    padded=$(echo "$padded" | tr '_-' '/+')
    echo "$padded" | base64 -d 2>/dev/null
}

# Parse JWT token
IFS='.' read -ra JWT_PARTS <<< "$CLOUDFLARE_TOKEN"

if [ ${#JWT_PARTS[@]} -ne 3 ]; then
    echo -e "${RED}Error: Invalid JWT token format${NC}"
    exit 1
fi

# Decode the payload
PAYLOAD=$(decode_base64_url "${JWT_PARTS[1]}")

if [ -z "$PAYLOAD" ]; then
    echo -e "${RED}Error: Failed to decode JWT payload${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Successfully decoded JWT token${NC}"
echo ""

# Install jq if needed
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    sudo apt-get update -qq
    sudo apt-get install -y jq
fi

# Extract fields
ACCOUNT_TAG=$(echo "$PAYLOAD" | jq -r '.a // empty')
TUNNEL_SECRET=$(echo "$PAYLOAD" | jq -r '.s // empty')
TUNNEL_ID=$(echo "$PAYLOAD" | jq -r '.t // empty')

if [ -z "$ACCOUNT_TAG" ] || [ -z "$TUNNEL_SECRET" ] || [ -z "$TUNNEL_ID" ]; then
    echo -e "${RED}Error: Failed to extract required fields from JWT token${NC}"
    echo "Payload:"
    echo "$PAYLOAD" | jq '.'
    exit 1
fi

echo -e "${GREEN}✓ Successfully extracted credentials:${NC}"
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