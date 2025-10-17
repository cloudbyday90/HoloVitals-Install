#!/bin/bash

# Cloudflare Error 1033 Diagnostic Script
# Diagnoses tunnel connectivity issues

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
echo "Cloudflare Error 1033 Diagnostic"
echo "=================================="
echo ""

if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

# 1. Check what's actually listening on port 3000
echo "=================================="
echo "1. PORT 3000 DETAILED CHECK"
echo "=================================="
echo ""

print_status "Checking what's listening on port 3000..."
if netstat -tulpn 2>/dev/null | grep -q ":3000 "; then
    print_success "Port 3000 is listening"
    echo ""
    echo "Process details:"
    netstat -tulpn 2>/dev/null | grep ":3000 "
    echo ""
    
    # Get the PID
    PID=$(netstat -tulpn 2>/dev/null | grep ":3000 " | awk '{print $7}' | cut -d'/' -f1)
    if [ -n "$PID" ]; then
        print_status "Process ID: $PID"
        print_status "Process details:"
        ps aux | grep $PID | grep -v grep
    fi
elif ss -tulpn 2>/dev/null | grep -q ":3000 "; then
    print_success "Port 3000 is listening"
    echo ""
    echo "Process details:"
    ss -tulpn 2>/dev/null | grep ":3000 "
else
    print_error "Port 3000 is NOT listening"
    echo ""
    print_status "Checking HoloVitals service..."
    systemctl status holovitals --no-pager -l
    exit 1
fi

echo ""

# 2. Test local connectivity with detailed output
echo "=================================="
echo "2. LOCAL CONNECTIVITY TEST"
echo "=================================="
echo ""

print_status "Testing http://localhost:3000 with verbose output..."
echo ""

# Test with curl verbose
curl -v http://localhost:3000 2>&1 | head -30

echo ""
echo ""

# Get just the status code
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
print_status "HTTP Status Code: $HTTP_CODE"

if [ "$HTTP_CODE" = "000" ]; then
    print_error "Cannot connect to application"
elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
    print_success "Application responds correctly"
else
    print_warning "Application returns HTTP $HTTP_CODE"
fi

echo ""

# 3. Check Cloudflared configuration in detail
echo "=================================="
echo "3. CLOUDFLARED CONFIGURATION"
echo "=================================="
echo ""

if [ -f /etc/cloudflared/config.yml ]; then
    print_success "Config file exists"
    echo ""
    echo "Full configuration:"
    cat /etc/cloudflared/config.yml
    echo ""
    
    # Extract and verify each part
    TUNNEL_ID=$(grep "^tunnel:" /etc/cloudflared/config.yml | awk '{print $2}')
    SERVICE_URL=$(grep "service: http" /etc/cloudflared/config.yml | head -1 | awk '{print $2}')
    HOSTNAME=$(grep "hostname:" /etc/cloudflared/config.yml | awk '{print $2}')
    
    print_status "Tunnel ID: $TUNNEL_ID"
    print_status "Service URL: $SERVICE_URL"
    print_status "Hostname: $HOSTNAME"
    
    # Check if service URL matches what's actually running
    if [ "$SERVICE_URL" != "http://localhost:3000" ]; then
        print_error "Config points to $SERVICE_URL but should be http://localhost:3000"
    else
        print_success "Service URL is correct"
    fi
else
    print_error "Config file not found"
    exit 1
fi

echo ""

# 4. Check Cloudflared service status
echo "=================================="
echo "4. CLOUDFLARED SERVICE STATUS"
echo "=================================="
echo ""

if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared is running"
    echo ""
    systemctl status cloudflared --no-pager -l | tail -20
else
    print_error "Cloudflared is NOT running"
    systemctl status cloudflared --no-pager -l
    exit 1
fi

echo ""

# 5. Check recent Cloudflared logs for connection info
echo "=================================="
echo "5. CLOUDFLARED LOGS (Last 50 lines)"
echo "=================================="
echo ""

journalctl -u cloudflared.service -n 50 --no-pager

echo ""

# 6. Test if cloudflared can reach the local service
echo "=================================="
echo "6. CLOUDFLARED TO APP CONNECTIVITY"
echo "=================================="
echo ""

print_status "Testing if cloudflared can reach http://localhost:3000..."

# Check if there are any firewall rules blocking localhost
print_status "Checking firewall rules..."
if command -v ufw &> /dev/null; then
    ufw status | grep -i "3000\|localhost" || echo "No specific rules for port 3000"
fi

echo ""

# Check if there are connection errors in logs
print_status "Checking for connection errors in logs..."
if journalctl -u cloudflared.service -n 100 --no-pager | grep -i "error\|failed\|refused"; then
    print_warning "Found errors in cloudflared logs (see above)"
else
    print_success "No obvious errors in recent logs"
fi

echo ""

# 7. Check credentials
echo "=================================="
echo "7. CLOUDFLARED CREDENTIALS"
echo "=================================="
echo ""

if [ -f /etc/cloudflared/credentials.json ]; then
    print_success "Credentials file exists"
    
    if jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
        print_success "Credentials file is valid JSON"
        
        CREDS_TUNNEL_ID=$(jq -r '.TunnelID' /etc/cloudflared/credentials.json)
        print_status "Credentials Tunnel ID: $CREDS_TUNNEL_ID"
        
        if [ "$CREDS_TUNNEL_ID" != "$TUNNEL_ID" ]; then
            print_error "MISMATCH: Credentials tunnel ID ($CREDS_TUNNEL_ID) != Config tunnel ID ($TUNNEL_ID)"
        else
            print_success "Tunnel IDs match"
        fi
    else
        print_error "Credentials file is invalid JSON"
    fi
else
    print_error "Credentials file not found"
fi

echo ""

# 8. Test actual tunnel connectivity
echo "=================================="
echo "8. TUNNEL CONNECTIVITY TEST"
echo "=================================="
echo ""

print_status "Testing connection to your domain..."
DOMAIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://alpha.holovitals.net 2>/dev/null || echo "000")
print_status "Domain HTTP Status: $DOMAIN_CODE"

if [ "$DOMAIN_CODE" = "000" ]; then
    print_error "Cannot reach domain"
elif [ "$DOMAIN_CODE" = "1033" ] || [ "$DOMAIN_CODE" = "502" ] || [ "$DOMAIN_CODE" = "503" ]; then
    print_error "Domain returns error $DOMAIN_CODE (tunnel issue)"
elif [ "$DOMAIN_CODE" = "200" ] || [ "$DOMAIN_CODE" = "301" ] || [ "$DOMAIN_CODE" = "302" ]; then
    print_success "Domain is accessible!"
else
    print_warning "Domain returns HTTP $DOMAIN_CODE"
fi

echo ""

# 9. Summary and recommendations
echo "=================================="
echo "9. DIAGNOSIS SUMMARY"
echo "=================================="
echo ""

ISSUES=0

# Check if app is responding locally
if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "301" ] && [ "$HTTP_CODE" != "302" ]; then
    print_error "ISSUE 1: Application not responding correctly locally (HTTP $HTTP_CODE)"
    echo "  This is the root cause of Error 1033"
    echo "  Fix: Check application logs: journalctl -u holovitals.service -n 100"
    ISSUES=$((ISSUES + 1))
else
    print_success "Application responds correctly locally"
fi

# Check tunnel IDs match
if [ "$CREDS_TUNNEL_ID" != "$TUNNEL_ID" ]; then
    print_error "ISSUE 2: Tunnel ID mismatch between credentials and config"
    echo "  Credentials: $CREDS_TUNNEL_ID"
    echo "  Config: $TUNNEL_ID"
    echo "  Fix: Update credentials or config to match"
    ISSUES=$((ISSUES + 1))
fi

# Check service URL
if [ "$SERVICE_URL" != "http://localhost:3000" ]; then
    print_error "ISSUE 3: Config points to wrong URL: $SERVICE_URL"
    echo "  Fix: Update config to point to http://localhost:3000"
    ISSUES=$((ISSUES + 1))
fi

# Check if cloudflared is running
if ! systemctl is-active --quiet cloudflared; then
    print_error "ISSUE 4: Cloudflared service not running"
    echo "  Fix: sudo systemctl start cloudflared"
    ISSUES=$((ISSUES + 1))
fi

echo ""

if [ $ISSUES -eq 0 ]; then
    print_success "No obvious issues detected"
    echo ""
    echo "If you're still getting Error 1033:"
    echo "  1. Wait 30-60 seconds for tunnel to fully connect"
    echo "  2. Check Cloudflare dashboard for tunnel status"
    echo "  3. Try restarting cloudflared: sudo systemctl restart cloudflared"
    echo "  4. Check if domain DNS is properly configured"
else
    print_error "Found $ISSUES issue(s) - see above for fixes"
fi

echo ""
echo "=================================="
echo "Diagnostic Complete"
echo "=================================="