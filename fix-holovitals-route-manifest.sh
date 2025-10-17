#!/bin/bash

# HoloVitals Route Manifest Fix Script
# Fixes the "routeManifest.dataRoutes is not iterable" error

echo "=============================================="
echo "HoloVitals Route Manifest Fix Script"
echo "=============================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_section "1. STOPPING HOLOVITALS SERVICE"
systemctl stop holovitals
print_success "Service stopped"

print_section "2. BACKING UP CURRENT BUILD"
cd /opt/HoloVitals
if [ -d ".next" ]; then
    timestamp=$(date +%Y%m%d_%H%M%S)
    mv .next .next.backup_$timestamp
    print_success "Backed up .next to .next.backup_$timestamp"
else
    print_warning ".next directory not found (may be first build)"
fi

if [ -d "node_modules" ]; then
    print_success "node_modules directory exists"
else
    print_error "node_modules directory not found"
fi

print_section "3. CLEARING BUILD CACHE"
rm -rf .next/cache
rm -rf .next/server
rm -rf .next/static
print_success "Cleared build cache"

print_section "4. CHECKING NEXT.JS VERSION"
current_version=$(npm list next --depth=0 2>/dev/null | grep next@ | sed 's/.*next@//' | sed 's/ .*//')
echo "Current Next.js version: $current_version"

print_section "5. REINSTALLING DEPENDENCIES"
echo "This may take a few minutes..."
npm install --legacy-peer-deps
if [ $? -eq 0 ]; then
    print_success "Dependencies reinstalled successfully"
else
    print_error "Failed to reinstall dependencies"
    exit 1
fi

print_section "6. REBUILDING APPLICATION"
echo "Building Next.js application..."
npm run build
if [ $? -eq 0 ]; then
    print_success "Build completed successfully"
else
    print_error "Build failed"
    echo ""
    echo "Common causes:"
    echo "1. Missing environment variables in .env.local"
    echo "2. Database connection issues"
    echo "3. TypeScript errors in code"
    echo ""
    echo "Check build logs above for specific errors"
    exit 1
fi

print_section "7. VERIFYING BUILD OUTPUT"
if [ -d ".next" ]; then
    print_success ".next directory created"
    
    if [ -f ".next/BUILD_ID" ]; then
        build_id=$(cat .next/BUILD_ID)
        print_success "Build ID: $build_id"
    fi
    
    if [ -d ".next/server" ]; then
        print_success "Server build exists"
    else
        print_error "Server build missing"
    fi
    
    if [ -d ".next/static" ]; then
        print_success "Static assets exist"
    else
        print_error "Static assets missing"
    fi
else
    print_error ".next directory not created"
    exit 1
fi

print_section "8. CHECKING ENVIRONMENT CONFIGURATION"
if [ -f ".env.local" ]; then
    print_success ".env.local exists"
    
    # Check for required variables
    required_vars=("DATABASE_URL" "NEXTAUTH_URL" "NEXTAUTH_SECRET")
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=" .env.local; then
            print_success "$var is set"
        else
            print_error "$var is NOT set"
        fi
    done
else
    print_error ".env.local not found"
    echo "Create .env.local with required variables:"
    echo "  DATABASE_URL=postgresql://..."
    echo "  NEXTAUTH_URL=http://localhost:3000"
    echo "  NEXTAUTH_SECRET=..."
fi

print_section "9. STARTING HOLOVITALS SERVICE"
systemctl start holovitals
sleep 5

if systemctl is-active --quiet holovitals; then
    print_success "HoloVitals service started successfully"
else
    print_error "HoloVitals service failed to start"
    echo ""
    echo "Check logs with: journalctl -u holovitals.service -n 50"
    exit 1
fi

print_section "10. TESTING APPLICATION"
echo "Waiting for application to initialize..."
sleep 10

http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
echo "HTTP Status Code: $http_code"

if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
    print_success "Application is responding correctly!"
else
    print_warning "Application returned status $http_code"
    echo "Check logs: journalctl -u holovitals.service -n 50"
fi

print_section "11. FINAL STATUS CHECK"
echo "Service Status:"
systemctl status holovitals --no-pager -l | tail -10

echo ""
echo "Recent Logs:"
journalctl -u holovitals.service -n 20 --no-pager

print_section "SUMMARY"
if systemctl is-active --quiet holovitals && [ "$http_code" = "200" -o "$http_code" = "301" -o "$http_code" = "302" ]; then
    print_success "Fix completed successfully!"
    echo ""
    echo "Your HoloVitals application should now be working."
    echo "Access it at: http://localhost:3000"
    echo ""
    echo "If using Cloudflare tunnel, restart it:"
    echo "  sudo systemctl restart cloudflared"
else
    print_error "Issues remain - review the output above"
    echo ""
    echo "Next steps:"
    echo "1. Check logs: journalctl -u holovitals.service -n 100"
    echo "2. Verify .env.local configuration"
    echo "3. Test database connection"
    echo "4. Check for port conflicts"
fi

echo ""
echo "=============================================="
echo "Fix Script Complete"
echo "=============================================="