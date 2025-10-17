#!/bin/bash

# Fix Tunnel Connection Errors
# Addresses "accept stream listener" and "context canceled" errors

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
echo "Fix Tunnel Connection Errors"
echo "=================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# 1. Check HoloVitals service
echo "=================================="
echo "1. HOLOVITALS SERVICE CHECK"
echo "=================================="
echo ""

if systemctl is-active --quiet holovitals; then
    print_success "HoloVitals service is running"
    
    # Check if it's stable (not restarting)
    RESTART_COUNT=$(systemctl show holovitals -p NRestarts --value)
    print_status "Service restart count: $RESTART_COUNT"
    
    if [ "$RESTART_COUNT" -gt 10 ]; then
        print_warning "Service has restarted $RESTART_COUNT times - may be unstable"
    fi
else
    print_error "HoloVitals service is NOT running"
    print_status "Starting service..."
    systemctl start holovitals
    sleep 5
    
    if systemctl is-active --quiet holovitals; then
        print_success "Service started"
    else
        print_error "Service failed to start"
        journalctl -u holovitals.service -n 30 --no-pager
        exit 1
    fi
fi

echo ""

# 2. Test application thoroughly
echo "=================================="
echo "2. APPLICATION CONNECTIVITY TEST"
echo "=================================="
echo ""

print_status "Testing http://localhost:3000 (10 attempts)..."
SUCCESS_COUNT=0
FAIL_COUNT=0

for i in {1..10}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo "  Attempt $i: HTTP $HTTP_CODE ✓"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "  Attempt $i: HTTP $HTTP_CODE ✗"
    fi
    
    sleep 1
done

echo ""
print_status "Results: $SUCCESS_COUNT successful, $FAIL_COUNT failed"

if [ $FAIL_COUNT -gt 3 ]; then
    print_error "Application is unstable or not responding consistently"
    echo ""
    print_status "Checking application logs..."
    journalctl -u holovitals.service -n 50 --no-pager
    echo ""
    print_warning "Fix application stability before continuing"
    exit 1
elif [ $FAIL_COUNT -gt 0 ]; then
    print_warning "Application has intermittent issues"
else
    print_success "Application is responding consistently"
fi

echo ""

# 3. Check for port conflicts
echo "=================================="
echo "3. PORT CONFLICT CHECK"
echo "=================================="
echo ""

print_status "Checking what's on port 3000..."
netstat -tulpn 2>/dev/null | grep ":3000 " || ss -tulpn 2>/dev/null | grep ":3000 "

echo ""

# 4. Check localhost connectivity
echo "=================================="
echo "4. LOCALHOST CONNECTIVITY"
echo "=================================="
echo ""

print_status "Testing localhost resolution..."
if ping -c 3 localhost > /dev/null 2>&1; then
    print_success "localhost is reachable"
else
    print_error "Cannot ping localhost"
fi

print_status "Testing 127.0.0.1..."
if ping -c 3 127.0.0.1 > /dev/null 2>&1; then
    print_success "127.0.0.1 is reachable"
else
    print_error "Cannot ping 127.0.0.1"
fi

echo ""

# 5. Check firewall rules
echo "=================================="
echo "5. FIREWALL CHECK"
echo "=================================="
echo ""

if command -v ufw &> /dev/null; then
    print_status "Checking UFW rules..."
    ufw status | grep -i "3000\|localhost" || echo "No specific rules for port 3000"
    
    # Ensure localhost is allowed
    print_status "Ensuring localhost traffic is allowed..."
    ufw allow from 127.0.0.1 to any port 3000 2>/dev/null || true
fi

echo ""

# 6. Stop cloudflared and test direct connection
echo "=================================="
echo "6. DIRECT CONNECTION TEST"
echo "=================================="
echo ""

print_status "Stopping cloudflared temporarily..."
systemctl stop cloudflared
sleep 2

print_status "Testing direct connection without cloudflared..."
DIRECT_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null || echo "000")
print_status "Direct connection HTTP code: $DIRECT_CODE"

if [ "$DIRECT_CODE" = "200" ] || [ "$DIRECT_CODE" = "301" ] || [ "$DIRECT_CODE" = "302" ]; then
    print_success "Direct connection works"
else
    print_error "Direct connection fails - application issue"
    print_status "Restarting HoloVitals service..."
    systemctl restart holovitals
    sleep 10
    
    RETRY_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost:3000 2>/dev/null || echo "000")
    if [ "$RETRY_CODE" = "200" ] || [ "$RETRY_CODE" = "301" ] || [ "$RETRY_CODE" = "302" ]; then
        print_success "Application works after restart"
    else
        print_error "Application still not working"
        journalctl -u holovitals.service -n 50 --no-pager
        exit 1
    fi
fi

echo ""

# 7. Update cloudflared config with connection settings
echo "=================================="
echo "7. CLOUDFLARED CONFIGURATION"
echo "=================================="
echo ""

print_status "Updating cloudflared config with connection settings..."

# Backup config
cp /etc/cloudflared/config.yml /etc/cloudflared/config.yml.backup_$(date +%Y%m%d_%H%M%S)

# Create optimized config
cat > /etc/cloudflared/config.yml << 'EOF'
tunnel: 573f4a9f-f0aa-4bce-8b78-a54eba1205d7
credentials-file: /etc/cloudflared/credentials.json

# Connection settings
protocol: quic
no-autoupdate: true

# Logging
loglevel: info

ingress:
  - hostname: alpha.holovitals.net
    service: http://localhost:3000
    originRequest:
      connectTimeout: 30s
      noTLSVerify: false
      noHappyEyeballs: false
      keepAliveConnections: 100
      keepAliveTimeout: 90s
      httpHostHeader: alpha.holovitals.net
  - service: http_status:404
EOF

print_success "Config updated with connection settings"

echo ""
print_status "New configuration:"
cat /etc/cloudflared/config.yml

echo ""

# 8. Start cloudflared
echo "=================================="
echo "8. STARTING CLOUDFLARED"
echo "=================================="
echo ""

print_status "Starting cloudflared with new configuration..."
systemctl start cloudflared

sleep 5

if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared is running"
else
    print_error "Cloudflared failed to start"
    journalctl -u cloudflared.service -n 30 --no-pager
    exit 1
fi

# 9. Monitor for errors
echo ""
print_status "Monitoring for errors (30 seconds)..."
sleep 30

echo ""
print_status "Recent logs:"
journalctl -u cloudflared.service -n 30 --no-pager | tail -20

echo ""
print_status "Checking for connection errors..."
if journalctl -u cloudflared.service -n 50 --no-pager | grep -i "failed to serve\|context canceled\|accept stream"; then
    print_warning "Still seeing connection errors (see above)"
    echo ""
    print_status "This may indicate:"
    echo "  1. Application is not stable"
    echo "  2. Network configuration issue"
    echo "  3. Cloudflare edge issue (wait and retry)"
else
    print_success "No connection errors in recent logs"
fi

# 10. Test domain
echo ""
echo "=================================="
echo "10. DOMAIN TEST"
echo "=================================="
echo ""

print_status "Testing domain (may take a moment)..."
DOMAIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://alpha.holovitals.net 2>/dev/null || echo "000")
print_status "Domain HTTP Status: $DOMAIN_CODE"

if [ "$DOMAIN_CODE" = "200" ] || [ "$DOMAIN_CODE" = "301" ] || [ "$DOMAIN_CODE" = "302" ]; then
    print_success "✅ Domain is accessible!"
    echo ""
    echo "Your site is working: https://alpha.holovitals.net"
elif [ "$DOMAIN_CODE" = "530" ] || [ "$DOMAIN_CODE" = "1033" ]; then
    print_warning "Still getting Error $DOMAIN_CODE"
    echo ""
    echo "Next steps:"
    echo "  1. Wait 2-3 minutes for tunnel to stabilize"
    echo "  2. Check Cloudflare dashboard for tunnel status"
    echo "  3. Monitor logs: sudo journalctl -u cloudflared.service -f"
    echo "  4. Verify application: curl http://localhost:3000"
else
    print_warning "Domain returns HTTP $DOMAIN_CODE"
fi

echo ""
echo "=================================="
echo "Fix Complete"
echo "=================================="
echo ""
echo "Monitor tunnel:"
echo "  sudo journalctl -u cloudflared.service -f"
echo ""
echo "Check application:"
echo "  sudo systemctl status holovitals"
echo "  curl http://localhost:3000"