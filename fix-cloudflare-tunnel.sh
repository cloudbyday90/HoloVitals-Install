#!/bin/bash
# Standalone Fix Script for Cloudflare Tunnel Authentication Issues

echo "=========================================="
echo "Cloudflare Tunnel Fix Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR]${NC} Please do not run as root"
    echo "Run as your regular user (the script will use sudo when needed)"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} This script will:"
echo "  1. Pull latest fixes from repository"
echo "  2. Stop existing Cloudflare tunnel"
echo "  3. Ask for your Cloudflare tunnel token"
echo "  4. Recreate credentials file in correct format"
echo "  5. Restart Cloudflare tunnel"
echo "  6. Verify tunnel is working"
echo ""

read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Step 1: Pull latest changes
echo -e "${BLUE}[STEP 1]${NC} Pulling latest changes from repository..."

REPO_DIR="$HOME/HoloVitals"
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${RED}[ERROR]${NC} HoloVitals repository not found at $REPO_DIR"
    exit 1
fi

cd "$REPO_DIR"

# Check if it's a git repository
if [ ! -d ".git" ]; then
    echo -e "${RED}[ERROR]${NC} Not a git repository"
    exit 1
fi

# Pull latest changes
echo "Pulling from modular-installer-v2 branch..."
git fetch origin modular-installer-v2
git checkout modular-installer-v2
git pull origin modular-installer-v2

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS]${NC} Latest changes pulled"
else
    echo -e "${RED}[ERROR]${NC} Failed to pull latest changes"
    exit 1
fi

echo ""

# Step 2: Stop existing Cloudflare tunnel
echo -e "${BLUE}[STEP 2]${NC} Stopping existing Cloudflare tunnel..."

if systemctl is-active --quiet cloudflared; then
    sudo systemctl stop cloudflared
    echo -e "${GREEN}[SUCCESS]${NC} Cloudflare tunnel stopped"
else
    echo -e "${YELLOW}[INFO]${NC} Cloudflare tunnel was not running"
fi

echo ""

# Step 3: Get Cloudflare tunnel token
echo -e "${BLUE}[STEP 3]${NC} Cloudflare Tunnel Token"
echo ""
echo "To get your Cloudflare Tunnel token:"
echo "1. Go to https://one.dash.cloudflare.com/"
echo "2. Navigate to Networks > Tunnels"
echo "3. Create a new tunnel or select existing"
echo "4. Copy the tunnel token (starts with 'eyJ...')"
echo ""

# Enhanced token validation
validate_cloudflare_token() {
    local token="$1"
    
    if [ -z "$token" ]; then
        return 1
    fi
    
    if [[ ! "$token" =~ ^eyJ ]]; then
        echo -e "${RED}[ERROR]${NC} Invalid token format: Token must start with eyJ"
        return 1
    fi
    
    local payload
    payload=$(echo "$token" | cut -d'.' -f2)
    
    if [ -z "$payload" ]; then
        echo -e "${RED}[ERROR]${NC} Invalid token format: Cannot extract payload"
        return 1
    fi
    
    local decoded
    decoded=$(echo "$payload" | base64 -d 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR]${NC} Invalid token format: Cannot decode payload"
        return 1
    fi
    
    if ! echo "$decoded" | jq -e '.t' &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Invalid token format: Missing tunnel ID field"
        return 1
    fi
    
    if ! echo "$decoded" | jq -e '.a' &>/dev/null || ! echo "$decoded" | jq -e '.s' &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Invalid token format: Missing required authentication fields"
        return 1
    fi
    
    return 0
}

while true; do
    read -p "Enter your Cloudflare Tunnel token: " CLOUDFLARE_TOKEN
    
    if [ -z "$CLOUDFLARE_TOKEN" ]; then
        echo -e "${RED}[ERROR]${NC} Token is required"
        continue
    fi
    
    if validate_cloudflare_token "$CLOUDFLARE_TOKEN"; then
        echo -e "${GREEN}[SUCCESS]${NC} Token validation passed"
        break
    else
        echo -e "${RED}[ERROR]${NC} Invalid token format, please try again"
        echo ""
    fi
done

echo ""

# Step 4: Extract tunnel information and create credentials
echo -e "${BLUE}[STEP 4]${NC} Creating credentials file in correct format..."

# Extract information from JWT token
TOKEN_PAYLOAD=$(echo "$CLOUDFLARE_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null)

TUNNEL_ID=$(echo "$TOKEN_PAYLOAD" | jq -r '.t' 2>/dev/null || echo "")
ACCOUNT_TAG=$(echo "$TOKEN_PAYLOAD" | jq -r '.a' 2>/dev/null || echo "")
TUNNEL_SECRET=$(echo "$TOKEN_PAYLOAD" | jq -r '.s' 2>/dev/null || echo "")

if [ -z "$TUNNEL_ID" ] || [ -z "$ACCOUNT_TAG" ] || [ -z "$TUNNEL_SECRET" ]; then
    echo -e "${RED}[ERROR]${NC} Failed to extract tunnel information from token"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Extracted tunnel information:"
echo "  Tunnel ID: $TUNNEL_ID"
echo "  Account Tag: $ACCOUNT_TAG"
echo ""

# Get domain name
echo "Enter your domain name (e.g., alpha.holovitals.net):"
read -p "Domain: " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}[ERROR]${NC} Domain name is required"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Domain: $DOMAIN_NAME"
echo ""

# Create cloudflared directory if it doesn't exist
sudo mkdir -p /etc/cloudflared

# Create credentials.json with proper format
echo "Creating credentials.json..."
sudo bash -c "cat > /etc/cloudflared/credentials.json << EOF
{
  &quot;AccountTag&quot;: &quot;$ACCOUNT_TAG&quot;,
  &quot;TunnelSecret&quot;: &quot;$TUNNEL_SECRET&quot;,
  &quot;TunnelID&quot;: &quot;$TUNNEL_ID&quot;
}
EOF"

sudo chmod 600 /etc/cloudflared/credentials.json
echo -e "${GREEN}[SUCCESS]${NC} Credentials file created"

# Create config.yml
echo "Creating config.yml..."
sudo bash -c "cat > /etc/cloudflared/config.yml << EOF
tunnel: $TUNNEL_ID
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: $DOMAIN_NAME
    service: http://localhost:3000
  - service: http_status:404
EOF"

echo -e "${GREEN}[SUCCESS]${NC} Configuration file created"
echo ""

# Step 5: Restart Cloudflare tunnel
echo -e "${BLUE}[STEP 5]${NC} Starting Cloudflare tunnel..."

sudo systemctl start cloudflared
sudo systemctl enable cloudflared

sleep 3

if systemctl is-active --quiet cloudflared; then
    echo -e "${GREEN}[SUCCESS]${NC} Cloudflare tunnel is running"
else
    echo -e "${RED}[ERROR]${NC} Cloudflare tunnel failed to start"
    echo "Check logs: sudo journalctl -u cloudflared -n 50"
    exit 1
fi

echo ""

# Step 6: Verify tunnel is working
echo -e "${BLUE}[STEP 6]${NC} Verifying tunnel connection..."
echo ""

sleep 5

# Check for authentication errors
if sudo journalctl -u cloudflared -n 50 --no-pager | grep -q "Unauthorized\|Failed to get tunnel"; then
    echo -e "${RED}[ERROR]${NC} Authentication errors detected"
    echo ""
    echo "Recent errors:"
    sudo journalctl -u cloudflared -n 20 --no-pager | grep "ERR"
    echo ""
    echo -e "${RED}[FAILED]${NC} Tunnel authentication failed"
    exit 1
else
    echo -e "${GREEN}[SUCCESS]${NC} No authentication errors"
fi

# Check for connection registration
if sudo journalctl -u cloudflared -n 50 --no-pager | grep -q "Connection.*registered"; then
    echo -e "${GREEN}[SUCCESS]${NC} Tunnel connection registered"
else
    echo -e "${YELLOW}[WARNING]${NC} Tunnel connection not yet registered (may still be connecting)"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Cloudflare Tunnel Fix Complete!${NC}"
echo "=========================================="
echo ""
echo "Your tunnel should now be working correctly."
echo "Your application will be accessible at: https://$DOMAIN_NAME"
echo ""
echo "To check tunnel status:"
echo "  sudo systemctl status cloudflared"
echo ""
echo "To view tunnel logs:"
echo "  sudo journalctl -u cloudflared -f"
echo ""