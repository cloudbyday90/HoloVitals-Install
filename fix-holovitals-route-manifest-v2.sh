#!/bin/bash

# HoloVitals Route Manifest Fix Script v2
# Fixes the "routeManifest.dataRoutes is not iterable" error
# Updated to handle correct application directory

echo "=============================================="
echo "HoloVitals Route Manifest Fix Script v2"
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

print_section "0. LOCATING APPLICATION DIRECTORY"

# Find the correct application directory
APP_DIR=""
if [ -d "/home/holovitalsdev" ]; then
    APP_DIR="/home/holovitalsdev"
    print_success "Found application at: $APP_DIR"
elif [ -d "/opt/HoloVitals" ]; then
    APP_DIR="/opt/HoloVitals"
    print_success "Found application at: $APP_DIR"
else
    print_error "Cannot find HoloVitals application directory"
    echo "Searched in:"
    echo "  - /home/holovitalsdev"
    echo "  - /opt/HoloVitals"
    exit 1
fi

cd "$APP_DIR" || exit 1
print_success "Changed to directory: $(pwd)"

# Check for package.json
if [ ! -f "package.json" ]; then
    print_error "package.json not found in $APP_DIR"
    exit 1
fi

print_section "1. STOPPING HOLOVITALS SERVICE"
systemctl stop holovitals
sleep 2
print_success "Service stopped"

print_section "2. BACKING UP CURRENT BUILD"
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
    print_warning "node_modules directory not found - will install"
fi

print_section "3. CLEARING BUILD CACHE"
rm -rf .next/cache 2>/dev/null
rm -rf .next/server 2>/dev/null
rm -rf .next/static 2>/dev/null
print_success "Cleared build cache"

print_section "4. CHECKING NEXT.JS VERSION"
if [ -f "package.json" ]; then
    next_version=$(grep '"next"' package.json | head -1 | sed 's/.*"next": "//' | sed 's/".*//')
    echo "Next.js version in package.json: $next_version"
fi

print_section "5. REINSTALLING DEPENDENCIES"
echo "This may take a few minutes..."
echo ""

# Try npm install first
npm install --legacy-peer-deps
install_result=$?

if [ $install_result -ne 0 ]; then
    print_error "npm install failed"
    echo ""
    echo "Trying alternative approach..."
    
    # Clean npm cache
    npm cache clean --force
    
    # Remove node_modules and package-lock
    rm -rf node_modules package-lock.json
    
    # Try again
    npm install --legacy-peer-deps
    install_result=$?
fi

if [ $install_result -eq 0 ]; then
    print_success "Dependencies installed successfully"
else
    print_error "Failed to install dependencies"
    echo ""
    echo "Manual steps to try:"
    echo "1. cd $APP_DIR"
    echo "2. rm -rf node_modules package-lock.json"
    echo "3. npm cache clean --force"
    echo "4. npm install --legacy-peer-deps"
    exit 1
fi

print_section "6. REBUILDING APPLICATION"
echo "Building Next.js application..."
echo ""

npm run build
build_result=$?

if [ $build_result -eq 0 ]; then
    print_success "Build completed successfully"
else
    print_error "Build failed"
    echo ""
    echo "Common causes:"
    echo "1. Missing environment variables in .env.local"
    echo "2. Database connection issues"
    echo "3. TypeScript errors in code"
    echo ""
    echo "Check the error messages above for details"
    echo ""
    echo "You can try building manually:"
    echo "  cd $APP_DIR"
    echo "  npm run build"
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
    print_error ".env.local not found in $APP_DIR"
    echo "Create .env.local with required variables:"
    echo "  DATABASE_URL=postgresql://..."
    echo "  NEXTAUTH_URL=http://localhost:3000"
    echo "  NEXTAUTH_SECRET=..."
fi

print_section "9. FIXING CLOUDFLARE TUNNEL CONFIGURATION"
if [ -f /etc/cloudflared/config.yml ]; then
    print_success "Cloudflared config found"
    
    # Check current port
    current_port=$(grep -oP 'localhost:\K[0-9]+' /etc/cloudflared/config.yml | head -1)
    echo "Current port in config: $current_port"
    
    if [ "$current_port" != "3000" ]; then
        print_warning "Cloudflared is configured for port $current_port"
        echo "Updating to port 3000..."
        
        # Backup config
        cp /etc/cloudflared/config.yml /etc/cloudflared/config.yml.backup_$(date +%Y%m%d_%H%M%S)
        
        # Update port to 3000
        sed -i "s/localhost:$current_port/localhost:3000/g" /etc/cloudflared/config.yml
        
        print_success "Updated cloudflared config to use port 3000"
        echo ""
        echo "New configuration:"
        cat /etc/cloudflared/config.yml
    else
        print_success "Cloudflared already configured for port 3000"
    fi
else
    print_warning "Cloudflared config not found at /etc/cloudflared/config.yml"
fi

print_section "10. STARTING HOLOVITALS SERVICE"
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

print_section "11. TESTING APPLICATION"
echo "Waiting for application to initialize..."
sleep 10

http_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000)
echo "HTTP Status Code: $http_code"

if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
    print_success "Application is responding correctly!"
else
    print_warning "Application returned status $http_code"
    echo "This might be normal if the app redirects or requires authentication"
    echo "Check logs: journalctl -u holovitals.service -n 50"
fi

print_section "12. RESTARTING CLOUDFLARED"
if systemctl is-active --quiet cloudflared; then
    echo "Restarting cloudflared to apply configuration changes..."
    systemctl restart cloudflared
    sleep 5
    
    if systemctl is-active --quiet cloudflared; then
        print_success "Cloudflared restarted successfully"
    else
        print_error "Cloudflared failed to restart"
        echo "Check logs: journalctl -u cloudflared.service -n 50"
    fi
else
    print_warning "Cloudflared service not running"
    echo "Start it with: sudo systemctl start cloudflared"
fi

print_section "13. FINAL STATUS CHECK"
echo "HoloVitals Service Status:"
systemctl status holovitals --no-pager -l | tail -10

echo ""
echo "Cloudflared Service Status:"
systemctl status cloudflared --no-pager -l | tail -10

echo ""
echo "Recent HoloVitals Logs:"
journalctl -u holovitals.service -n 10 --no-pager

print_section "SUMMARY"
holovitals_active=$(systemctl is-active holovitals)
cloudflared_active=$(systemctl is-active cloudflared)

echo "Service Status:"
echo "  HoloVitals: $holovitals_active"
echo "  Cloudflared: $cloudflared_active"
echo ""

if [ "$holovitals_active" = "active" ] && [ "$cloudflared_active" = "active" ]; then
    print_success "All services are running!"
    echo ""
    echo "Your HoloVitals application should now be accessible at:"
    echo "  - Local: http://localhost:3000"
    echo "  - Domain: https://alpha.holovitals.net"
    echo ""
    echo "Test with: curl https://alpha.holovitals.net"
else
    print_error "Some services are not running"
    echo ""
    echo "Check logs:"
    echo "  HoloVitals: journalctl -u holovitals.service -n 100"
    echo "  Cloudflared: journalctl -u cloudflared.service -n 100"
fi

echo ""
echo "=============================================="
echo "Fix Script Complete"
echo "=============================================="