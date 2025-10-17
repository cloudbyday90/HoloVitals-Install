#!/bin/bash

# Port and Service Validation Script
# Comprehensive check of HoloVitals application and Cloudflare tunnel

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
echo "Port and Service Validation"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# 1. Check HoloVitals Service
echo "=================================="
echo "1. HOLOVITALS SERVICE STATUS"
echo "=================================="
echo ""

if systemctl is-active --quiet holovitals; then
    print_success "HoloVitals service is running"
    systemctl status holovitals --no-pager -l | tail -15
else
    print_error "HoloVitals service is NOT running"
    echo ""
    echo "Service status:"
    systemctl status holovitals --no-pager -l
    echo ""
    echo "Recent logs:"
    journalctl -u holovitals.service -n 30 --no-pager
    exit 1
fi

echo ""

# 2. Check Ports
echo "=================================="
echo "2. PORT AVAILABILITY"
echo "=================================="
echo ""

print_status "Checking port 3000..."
if netstat -tuln 2>/dev/null | grep -q ":3000 " || ss -tuln 2>/dev/null | grep -q ":3000 "; then
    print_success "Port 3000 is listening"
    netstat -tuln 2>/dev/null | grep ":3000 " || ss -tuln 2>/dev/null | grep ":3000 "
else
    print_error "Port 3000 is NOT listening"
    echo ""
    print_status "Checking other common ports..."
    for port in 3001 3002 8080 8000; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Found application on port $port instead"
            netstat -tuln 2>/dev/null | grep ":$port " || ss -tuln 2>/dev/null | grep ":$port "
        fi
    done
fi

echo ""
print_status "All listening ports:"
netstat -tuln 2>/dev/null | grep LISTEN || ss -tuln 2>/dev/null | grep LISTEN

echo ""

# 3. Test Application Locally
echo "=================================="
echo "3. LOCAL APPLICATION TEST"
echo "=================================="
echo ""

print_status "Testing http://localhost:3000..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
echo "HTTP Status Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    print_success "Application responds correctly"
    echo ""
    echo "Response headers:"
    curl -I http://localhost:3000 2>/dev/null | head -10
elif [ "$HTTP_CODE" = "404" ]; then
    print_warning "Application returns 404 - app is running but may not be serving content"
    echo ""
    echo "Response headers:"
    curl -I http://localhost:3000 2>/dev/null | head -10
else
    print_error "Application is not responding (HTTP $HTTP_CODE)"
    echo ""
    print_status "Checking if process is running..."
    ps aux | grep -i node | grep -v grep
fi

echo ""

# 4. Check Cloudflared Service
echo "=================================="
echo "4. CLOUDFLARED SERVICE STATUS"
echo "=================================="
echo ""

if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared service is running"
    systemctl status cloudflared --no-pager -l | tail -15
else
    print_error "Cloudflared service is NOT running"
    echo ""
    echo "Service status:"
    systemctl status cloudflared --no-pager -l
    echo ""
    echo "Recent logs:"
    journalctl -u cloudflared.service -n 30 --no-pager
fi

echo ""

# 5. Check Cloudflared Configuration
echo "=================================="
echo "5. CLOUDFLARED CONFIGURATION"
echo "=================================="
echo ""

if [ -f /etc/cloudflared/config.yml ]; then
    print_success "Config file exists"
    echo ""
    echo "Configuration:"
    cat /etc/cloudflared/config.yml
    echo ""
    
    # Check port in config
    CONFIG_PORT=$(grep -oP 'localhost:\K[0-9]+' /etc/cloudflared/config.yml | head -1)
    echo "Configured port: $CONFIG_PORT"
    
    if [ "$CONFIG_PORT" != "3000" ]; then
        print_warning "Config points to port $CONFIG_PORT, but app should be on 3000"
        echo ""
        echo "To fix:"
        echo "  sudo sed -i 's/localhost:$CONFIG_PORT/localhost:3000/g' /etc/cloudflared/config.yml"
        echo "  sudo systemctl restart cloudflared"
    else
        print_success "Config points to correct port (3000)"
    fi
else
    print_error "Config file not found at /etc/cloudflared/config.yml"
fi

echo ""

# 6. Check Cloudflared Credentials
echo "=================================="
echo "6. CLOUDFLARED CREDENTIALS"
echo "=================================="
echo ""

if [ -f /etc/cloudflared/credentials.json ]; then
    print_success "Credentials file exists"
    echo "File permissions: $(ls -l /etc/cloudflared/credentials.json)"
    
    if jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
        print_success "Credentials file is valid JSON"
        TUNNEL_ID=$(jq -r '.TunnelID' /etc/cloudflared/credentials.json)
        echo "Tunnel ID: $TUNNEL_ID"
    else
        print_error "Credentials file is INVALID JSON"
    fi
else
    print_error "Credentials file not found"
fi

echo ""

# 7. Recent Cloudflared Logs
echo "=================================="
echo "7. RECENT CLOUDFLARED LOGS"
echo "=================================="
echo ""

journalctl -u cloudflared.service -n 50 --no-pager

echo ""

# 8. Network Connectivity
echo "=================================="
echo "8. NETWORK CONNECTIVITY"
echo "=================================="
echo ""

print_status "Testing connection to Cloudflare..."
if ping -c 3 1.1.1.1 > /dev/null 2>&1; then
    print_success "Can reach Cloudflare DNS (1.1.1.1)"
else
    print_error "Cannot reach Cloudflare DNS"
fi

echo ""

# 9. Process Information
echo "=================================="
echo "9. RUNNING PROCESSES"
echo "=================================="
echo ""

print_status "Node.js processes:"
ps aux | grep -i node | grep -v grep || echo "No Node.js processes found"

echo ""
print_status "Cloudflared processes:"
ps aux | grep -i cloudflared | grep -v grep || echo "No cloudflared processes found"

echo ""

# 10. Summary and Recommendations
echo "=================================="
echo "10. SUMMARY AND RECOMMENDATIONS"
echo "=================================="
echo ""

ISSUES=0

# Check HoloVitals
if ! systemctl is-active --quiet holovitals; then
    print_error "ISSUE: HoloVitals service not running"
    echo "  Fix: sudo systemctl start holovitals"
    ISSUES=$((ISSUES + 1))
fi

# Check port 3000
if ! netstat -tuln 2>/dev/null | grep -q ":3000 " && ! ss -tuln 2>/dev/null | grep -q ":3000 "; then
    print_error "ISSUE: Port 3000 not listening"
    echo "  Check: journalctl -u holovitals.service -n 50"
    ISSUES=$((ISSUES + 1))
fi

# Check application response
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "301" ] && [ "$HTTP_CODE" != "302" ]; then
    print_error "ISSUE: Application not responding correctly (HTTP $HTTP_CODE)"
    echo "  Check: journalctl -u holovitals.service -n 50"
    ISSUES=$((ISSUES + 1))
fi

# Check Cloudflared
if ! systemctl is-active --quiet cloudflared; then
    print_error "ISSUE: Cloudflared service not running"
    echo "  Fix: sudo systemctl start cloudflared"
    ISSUES=$((ISSUES + 1))
fi

# Check port mismatch
if [ -f /etc/cloudflared/config.yml ]; then
    CONFIG_PORT=$(grep -oP 'localhost:\K[0-9]+' /etc/cloudflared/config.yml | head -1)
    if [ "$CONFIG_PORT" != "3000" ]; then
        print_error "ISSUE: Port mismatch - config points to $CONFIG_PORT"
        echo "  Fix: sudo sed -i 's/localhost:$CONFIG_PORT/localhost:3000/g' /etc/cloudflared/config.yml"
        echo "       sudo systemctl restart cloudflared"
        ISSUES=$((ISSUES + 1))
    fi
fi

echo ""
if [ $ISSUES -eq 0 ]; then
    print_success "No critical issues detected"
    echo ""
    echo "If you still can't reach your site:"
    echo "  1. Check your domain DNS settings in Cloudflare dashboard"
    echo "  2. Verify tunnel is connected: sudo journalctl -u cloudflared.service -f"
    echo "  3. Test locally: curl http://localhost:3000"
else
    print_error "Found $ISSUES issue(s) - see recommendations above"
fi

echo ""
echo "=================================="
echo "Validation Complete"
echo "=================================="