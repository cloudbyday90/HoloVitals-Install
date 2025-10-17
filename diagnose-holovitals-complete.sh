#!/bin/bash

# HoloVitals Complete Diagnostic Script
# This script performs comprehensive diagnostics on the HoloVitals installation

echo "=============================================="
echo "HoloVitals Complete Diagnostic Script"
echo "=============================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 1. System Information
print_section "1. SYSTEM INFORMATION"
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Current Time: $(date)"
echo "Current User: $(whoami)"

# 2. Cloudflared Service Status
print_section "2. CLOUDFLARED SERVICE STATUS"
if systemctl is-active --quiet cloudflared; then
    print_success "Cloudflared service is running"
    systemctl status cloudflared --no-pager -l | tail -20
else
    print_error "Cloudflared service is NOT running"
    systemctl status cloudflared --no-pager -l
fi

# 3. Cloudflared Configuration
print_section "3. CLOUDFLARED CONFIGURATION"
if [ -f /etc/cloudflared/config.yml ]; then
    print_success "Config file exists at /etc/cloudflared/config.yml"
    echo ""
    echo "Configuration contents:"
    cat /etc/cloudflared/config.yml
else
    print_error "Config file NOT found at /etc/cloudflared/config.yml"
fi

# 4. Cloudflared Credentials
print_section "4. CLOUDFLARED CREDENTIALS"
if [ -f /etc/cloudflared/credentials.json ]; then
    print_success "Credentials file exists"
    echo "File permissions: $(ls -l /etc/cloudflared/credentials.json)"
    echo "File size: $(stat -f%z /etc/cloudflared/credentials.json 2>/dev/null || stat -c%s /etc/cloudflared/credentials.json) bytes"
    
    # Validate JSON
    if jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
        print_success "Credentials file is valid JSON"
        echo "Tunnel ID: $(jq -r '.TunnelID' /etc/cloudflared/credentials.json)"
    else
        print_error "Credentials file is INVALID JSON"
    fi
else
    print_error "Credentials file NOT found"
fi

# 5. HoloVitals Application Status
print_section "5. HOLOVITALS APPLICATION STATUS"
if systemctl is-active --quiet holovitals; then
    print_success "HoloVitals service is running"
    systemctl status holovitals --no-pager -l | tail -20
else
    print_error "HoloVitals service is NOT running"
    systemctl status holovitals --no-pager -l
fi

# 6. Port Checks
print_section "6. PORT AVAILABILITY CHECKS"
echo "Checking which ports are listening..."
echo ""

# Check port 3001
if netstat -tuln 2>/dev/null | grep -q ":3001 " || ss -tuln 2>/dev/null | grep -q ":3001 "; then
    print_success "Port 3001 is listening"
    netstat -tuln 2>/dev/null | grep ":3001 " || ss -tuln 2>/dev/null | grep ":3001 "
else
    print_error "Port 3001 is NOT listening"
fi

# Check port 3000
if netstat -tuln 2>/dev/null | grep -q ":3000 " || ss -tuln 2>/dev/null | grep -q ":3000 "; then
    print_warning "Port 3000 is listening (should be 3001)"
    netstat -tuln 2>/dev/null | grep ":3000 " || ss -tuln 2>/dev/null | grep ":3000 "
else
    echo "Port 3000 is not listening (expected)"
fi

# Check port 5432 (PostgreSQL)
if netstat -tuln 2>/dev/null | grep -q ":5432 " || ss -tuln 2>/dev/null | grep -q ":5432 "; then
    print_success "Port 5432 (PostgreSQL) is listening"
else
    print_error "Port 5432 (PostgreSQL) is NOT listening"
fi

echo ""
echo "All listening ports:"
netstat -tuln 2>/dev/null || ss -tuln 2>/dev/null

# 7. Local Application Test
print_section "7. LOCAL APPLICATION CONNECTIVITY TEST"
echo "Testing localhost:3001..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3001 | grep -q "200\|301\|302"; then
    print_success "Application responds on localhost:3001"
    echo "HTTP Status: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001)"
    echo ""
    echo "Response headers:"
    curl -I http://localhost:3001 2>/dev/null | head -10
else
    print_error "Application does NOT respond on localhost:3001"
    echo "HTTP Status: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3001)"
fi

echo ""
echo "Testing localhost:3000..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    print_warning "Application responds on localhost:3000 (config may need update)"
    echo "HTTP Status: $(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)"
else
    echo "No response on localhost:3000 (expected if app is on 3001)"
fi

# 8. Process Information
print_section "8. RUNNING PROCESSES"
echo "Node.js processes:"
ps aux | grep -i node | grep -v grep || echo "No Node.js processes found"
echo ""
echo "Cloudflared processes:"
ps aux | grep -i cloudflared | grep -v grep || echo "No cloudflared processes found"

# 9. Recent Logs
print_section "9. RECENT SERVICE LOGS"
echo "=== HoloVitals Service Logs (last 30 lines) ==="
journalctl -u holovitals.service -n 30 --no-pager
echo ""
echo "=== Cloudflared Service Logs (last 30 lines) ==="
journalctl -u cloudflared.service -n 30 --no-pager

# 10. Network Connectivity
print_section "10. NETWORK CONNECTIVITY"
echo "Testing connection to Cloudflare..."
if ping -c 3 1.1.1.1 > /dev/null 2>&1; then
    print_success "Can reach Cloudflare DNS (1.1.1.1)"
else
    print_error "Cannot reach Cloudflare DNS"
fi

echo ""
echo "Testing DNS resolution..."
if nslookup alpha.holovitals.net > /dev/null 2>&1; then
    print_success "DNS resolution works for alpha.holovitals.net"
    nslookup alpha.holovitals.net
else
    print_error "DNS resolution failed for alpha.holovitals.net"
fi

# 11. Environment Files
print_section "11. ENVIRONMENT CONFIGURATION"
if [ -f /opt/HoloVitals/.env.local ]; then
    print_success ".env.local exists in /opt/HoloVitals"
    echo "File size: $(stat -f%z /opt/HoloVitals/.env.local 2>/dev/null || stat -c%s /opt/HoloVitals/.env.local) bytes"
    echo "Key variables present:"
    grep -E "^(DATABASE_URL|NEXTAUTH_URL|NEXTAUTH_SECRET)" /opt/HoloVitals/.env.local | sed 's/=.*/=***REDACTED***/'
else
    print_error ".env.local NOT found in /opt/HoloVitals"
fi

# 12. Database Connection
print_section "12. DATABASE STATUS"
if systemctl is-active --quiet postgresql; then
    print_success "PostgreSQL service is running"
    
    # Try to connect to database
    if sudo -u postgres psql -d holovitals -c "SELECT 1;" > /dev/null 2>&1; then
        print_success "Can connect to holovitals database"
        echo "Database size:"
        sudo -u postgres psql -d holovitals -c "SELECT pg_size_pretty(pg_database_size('holovitals'));"
        echo ""
        echo "Tables in database:"
        sudo -u postgres psql -d holovitals -c "\dt" 2>/dev/null | head -20
    else
        print_error "Cannot connect to holovitals database"
    fi
else
    print_error "PostgreSQL service is NOT running"
fi

# 13. Disk Space
print_section "13. DISK SPACE"
df -h | grep -E "Filesystem|/$|/opt"

# 14. Memory Usage
print_section "14. MEMORY USAGE"
free -h

# 15. Summary and Recommendations
print_section "15. DIAGNOSTIC SUMMARY"
echo ""

# Check for common issues
ISSUES_FOUND=0

# Issue 1: Cloudflared not running
if ! systemctl is-active --quiet cloudflared; then
    print_error "ISSUE: Cloudflared service is not running"
    echo "  → Fix: sudo systemctl start cloudflared"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Issue 2: HoloVitals not running
if ! systemctl is-active --quiet holovitals; then
    print_error "ISSUE: HoloVitals service is not running"
    echo "  → Fix: sudo systemctl start holovitals"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Issue 3: Port 3001 not listening
if ! netstat -tuln 2>/dev/null | grep -q ":3001 " && ! ss -tuln 2>/dev/null | grep -q ":3001 "; then
    print_error "ISSUE: Application not listening on port 3001"
    echo "  → Check: journalctl -u holovitals.service -n 50"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Issue 4: Config pointing to wrong port
if [ -f /etc/cloudflared/config.yml ]; then
    if grep -q "localhost:3000" /etc/cloudflared/config.yml && ! netstat -tuln 2>/dev/null | grep -q ":3000 " && ! ss -tuln 2>/dev/null | grep -q ":3000 "; then
        print_error "ISSUE: Cloudflared config points to port 3000 but app is on 3001"
        echo "  → Fix: sudo sed -i 's/localhost:3000/localhost:3001/g' /etc/cloudflared/config.yml"
        echo "  → Then: sudo systemctl restart cloudflared"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# Issue 5: Invalid credentials
if [ -f /etc/cloudflared/credentials.json ]; then
    if ! jq empty /etc/cloudflared/credentials.json 2>/dev/null; then
        print_error "ISSUE: Cloudflared credentials file is invalid JSON"
        echo "  → Fix: Run the credentials fix script"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# Issue 6: PostgreSQL not running
if ! systemctl is-active --quiet postgresql; then
    print_error "ISSUE: PostgreSQL is not running"
    echo "  → Fix: sudo systemctl start postgresql"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Issue 7: Application returns 404
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3001 | grep -q "404"; then
    print_error "ISSUE: Application returns 404 on localhost:3001"
    echo "  → This suggests the app is running but not serving content correctly"
    echo "  → Check: journalctl -u holovitals.service -n 100"
    echo "  → Verify: .env.local configuration is correct"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""
if [ $ISSUES_FOUND -eq 0 ]; then
    print_success "No critical issues detected!"
    echo ""
    echo "If you're still experiencing problems, check:"
    echo "  1. Cloudflare dashboard for tunnel status"
    echo "  2. Application logs: journalctl -u holovitals.service -f"
    echo "  3. Cloudflared logs: journalctl -u cloudflared.service -f"
else
    echo -e "${RED}Found $ISSUES_FOUND issue(s) that need attention${NC}"
    echo ""
    echo "Review the issues above and apply the suggested fixes."
fi

echo ""
echo "=============================================="
echo "Diagnostic Complete"
echo "=============================================="
echo ""
echo "To save this output to a file, run:"
echo "  sudo bash diagnose-holovitals-complete.sh > diagnostic-report.txt 2>&1"