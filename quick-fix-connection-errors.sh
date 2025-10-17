#!/bin/bash

# HoloVitals Quick Connection Error Fix
# This script attempts to fix common Cloudflare tunnel connection errors
# Run with: sudo bash quick-fix-connection-errors.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo"
    exit 1
fi

print_header "HoloVitals Connection Error Quick Fix"
echo ""

# Step 1: Find HoloVitals installation
print_header "Step 1: Locating HoloVitals Installation"
HOLOVITALS_DIR=""
SEARCH_PATHS=(
    "/opt/HoloVitals"
    "/home/*/HoloVitals"
    "/home/holovitalsdev"
    "/var/www/HoloVitals"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [ -d "$path" ] 2>/dev/null; then
        HOLOVITALS_DIR="$path"
        print_success "Found HoloVitals at: $HOLOVITALS_DIR"
        break
    fi
done

if [ -z "$HOLOVITALS_DIR" ]; then
    print_error "HoloVitals directory not found"
    exit 1
fi
echo ""

# Step 2: Check application status
print_header "Step 2: Checking Application Status"
cd "$HOLOVITALS_DIR"

if [ ! -f "package.json" ]; then
    print_error "package.json not found"
    exit 1
fi

print_success "package.json found"

# Check if app is running
if pgrep -f "node.*3000" > /dev/null; then
    print_success "Application is running on port 3000"
else
    print_warning "Application not running, attempting to start..."
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        print_warning "Installing dependencies..."
        npm install
    fi
    
    # Start application in background
    nohup npm start > /tmp/holovitals-app.log 2>&1 &
    sleep 5
    
    if pgrep -f "node.*3000" > /dev/null; then
        print_success "Application started successfully"
    else
        print_error "Failed to start application"
        echo "Check logs: tail -f /tmp/holovitals-app.log"
        exit 1
    fi
fi
echo ""

# Step 3: Stop existing cloudflared
print_header "Step 3: Stopping Existing Cloudflared"
systemctl stop cloudflared 2>/dev/null || true
pkill -9 cloudflared 2>/dev/null || true
sleep 2
print_success "Stopped existing cloudflared processes"
echo ""

# Step 4: Backup and clean old configuration
print_header "Step 4: Cleaning Old Configuration"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

for dir in /etc/cloudflared /root/.cloudflared $HOME/.cloudflared; do
    if [ -d "$dir" ]; then
        print_warning "Backing up $dir to ${dir}.backup-${TIMESTAMP}"
        cp -r "$dir" "${dir}.backup-${TIMESTAMP}"
        rm -f "$dir/config.yml" "$dir/credentials.json" 2>/dev/null || true
    fi
done
print_success "Old configuration cleaned"
echo ""

# Step 5: Request tunnel token
print_header "Step 5: Tunnel Token Required"
echo ""
echo "Please provide your Cloudflare Tunnel Token:"
echo "(You can get this from: https://one.dash.cloudflare.com/)"
echo ""
read -p "Enter tunnel token: " TUNNEL_TOKEN

if [ -z "$TUNNEL_TOKEN" ]; then
    print_error "Tunnel token is required"
    exit 1
fi
echo ""

# Step 6: Create optimized configuration
print_header "Step 6: Creating Optimized Configuration"

mkdir -p /etc/cloudflared
cat > /etc/cloudflared/config.yml << EOF
tunnel: $(echo $TUNNEL_TOKEN | grep -oP '(?<=tunnel=)[a-f0-9-]+')
credentials-file: /etc/cloudflared/credentials.json

# Optimized connection settings
protocol: quic
no-autoupdate: true
grace-period: 30s
loglevel: info

# Connection optimization
retries: 5
max-backoff: 30s
initial-backoff: 1s

# Performance tuning
compression-quality: 0
metrics: localhost:2000

ingress:
  - hostname: alpha.holovitals.net
    service: http://localhost:3000
    originRequest:
      connectTimeout: 30s
      noTLSVerify: false
      keepAliveTimeout: 90s
      keepAliveConnections: 10
      httpHostHeader: alpha.holovitals.net
  - service: http_status:404
EOF

print_success "Configuration created"
echo ""

# Step 7: Extract and create credentials
print_header "Step 7: Creating Credentials"

# Extract tunnel ID and secret from token
TUNNEL_ID=$(echo $TUNNEL_TOKEN | grep -oP '(?<=tunnel=)[a-f0-9-]+')
TUNNEL_SECRET=$(echo $TUNNEL_TOKEN | grep -oP '(?<=secret=)[A-Za-z0-9+/=]+')

if [ -z "$TUNNEL_ID" ] || [ -z "$TUNNEL_SECRET" ]; then
    print_error "Invalid tunnel token format"
    exit 1
fi

# Create credentials file
cat > /etc/cloudflared/credentials.json << EOF
{
  "AccountTag": "",
  "TunnelSecret": "$TUNNEL_SECRET",
  "TunnelID": "$TUNNEL_ID"
}
EOF

chmod 600 /etc/cloudflared/credentials.json
print_success "Credentials created"
echo ""

# Step 8: Fix system permissions
print_header "Step 8: Fixing System Permissions"

# Fix ping_group_range
if ! grep -q "net.ipv4.ping_group_range = 0 2147483647" /etc/sysctl.conf; then
    echo "net.ipv4.ping_group_range = 0 2147483647" >> /etc/sysctl.conf
    sysctl -p
    print_success "Fixed ping_group_range"
else
    print_success "ping_group_range already configured"
fi
echo ""

# Step 9: Create systemd service
print_header "Step 9: Creating Systemd Service"

cat > /etc/systemd/system/cloudflared.service << 'EOF'
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=always
RestartSec=5
StandardOutput=append:/var/log/cloudflared.log
StandardError=append:/var/log/cloudflared.log

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudflared
print_success "Systemd service created"
echo ""

# Step 10: Start cloudflared
print_header "Step 10: Starting Cloudflared"
systemctl start cloudflared
sleep 5

if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared started successfully"
else
    print_error "Failed to start cloudflared"
    echo "Check logs: journalctl -u cloudflared -n 50"
    exit 1
fi
echo ""

# Step 11: Monitor for errors
print_header "Step 11: Monitoring Connection (30 seconds)"
echo ""
echo "Watching for connection errors..."
echo ""

timeout 30 journalctl -u cloudflared -f -n 0 2>&1 | while read line; do
    if echo "$line" | grep -qi "error\|failed\|cannot"; then
        echo -e "${RED}$line${NC}"
    elif echo "$line" | grep -qi "registered\|connected\|started"; then
        echo -e "${GREEN}$line${NC}"
    else
        echo "$line"
    fi
done || true

echo ""

# Step 12: Final status check
print_header "Step 12: Final Status Check"
echo ""

echo "Service Status:"
systemctl status cloudflared --no-pager -l | head -20
echo ""

echo "Recent Logs:"
journalctl -u cloudflared -n 20 --no-pager
echo ""

# Step 13: Test connectivity
print_header "Step 13: Testing Connectivity"
echo ""

echo "Testing domain: alpha.holovitals.net"
if curl -s -o /dev/null -w "%{http_code}" https://alpha.holovitals.net | grep -q "200\|301\|302"; then
    print_success "Domain is accessible!"
else
    print_warning "Domain test inconclusive (may need a few minutes to propagate)"
fi
echo ""

# Summary
print_header "Summary"
echo ""
echo "Configuration:"
echo "  - Tunnel ID: $TUNNEL_ID"
echo "  - Domain: alpha.holovitals.net"
echo "  - Local Service: http://localhost:3000"
echo "  - Protocol: QUIC"
echo ""
echo "Monitoring Commands:"
echo "  - View logs: journalctl -u cloudflared -f"
echo "  - Check status: systemctl status cloudflared"
echo "  - Restart service: systemctl restart cloudflared"
echo ""
echo "Log file: /var/log/cloudflared.log"
echo ""

if systemctl is-active --quiet cloudflared; then
    print_success "Setup complete! Monitor logs for any connection errors."
else
    print_error "Service not running. Check logs for details."
fi
echo ""