#!/bin/bash

# HoloVitals Route Manifest Fix Script v3
# Fixes the "routeManifest.dataRoutes is not iterable" error
# Auto-installs missing packages and handles missing build scripts

echo "=============================================="
echo "HoloVitals Route Manifest Fix Script v3"
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

print_section "1. CHECKING PACKAGE.JSON CONFIGURATION"

# Check if build script exists
if grep -q '"build"' package.json; then
    print_success "Build script found in package.json"
else
    print_error "Build script NOT found in package.json"
    echo ""
    echo "Adding build script to package.json..."
    
    # Backup package.json
    cp package.json package.json.backup_$(date +%Y%m%d_%H%M%S)
    
    # Add build script using jq if available, otherwise use sed
    if command -v jq &> /dev/null; then
        jq '.scripts.build = "next build"' package.json > package.json.tmp && mv package.json.tmp package.json
        print_success "Added build script using jq"
    else
        # Use sed to add build script
        sed -i '/"scripts": {/a\    "build": "next build",' package.json
        print_success "Added build script using sed"
    fi
fi

# Check if start script exists
if grep -q '"start"' package.json; then
    print_success "Start script found in package.json"
else
    print_warning "Start script NOT found in package.json"
    echo "Adding start script..."
    
    if command -v jq &> /dev/null; then
        jq '.scripts.start = "next start"' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        sed -i '/"scripts": {/a\    "start": "next start",' package.json
    fi
    print_success "Added start script"
fi

# Check if dev script exists
if grep -q '"dev"' package.json; then
    print_success "Dev script found in package.json"
else
    print_warning "Dev script NOT found in package.json"
    echo "Adding dev script..."
    
    if command -v jq &> /dev/null; then
        jq '.scripts.dev = "next dev"' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        sed -i '/"scripts": {/a\    "dev": "next dev",' package.json
    fi
    print_success "Added dev script"
fi

print_section "2. CHECKING REQUIRED PACKAGES"

# Check if Next.js is installed
if grep -q '"next"' package.json; then
    next_version=$(grep '"next"' package.json | head -1 | sed 's/.*"next": "//' | sed 's/".*//')
    print_success "Next.js found in package.json: $next_version"
else
    print_error "Next.js NOT found in package.json"
    echo "Adding Next.js to dependencies..."
    
    if command -v jq &> /dev/null; then
        jq '.dependencies.next = "latest"' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Add next to dependencies
        sed -i '/"dependencies": {/a\    "next": "latest",' package.json
    fi
    print_success "Added Next.js to dependencies"
fi

# Check for React
if grep -q '"react"' package.json; then
    print_success "React found in package.json"
else
    print_warning "React NOT found in package.json"
    echo "Adding React..."
    
    if command -v jq &> /dev/null; then
        jq '.dependencies.react = "latest" | .dependencies["react-dom"] = "latest"' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        sed -i '/"dependencies": {/a\    "react": "latest",\n    "react-dom": "latest",' package.json
    fi
    print_success "Added React and React-DOM"
fi

echo ""
echo "Current package.json scripts section:"
grep -A 10 '"scripts"' package.json | head -15

print_section "3. STOPPING HOLOVITALS SERVICE"
systemctl stop holovitals
sleep 2
print_success "Service stopped"

print_section "4. BACKING UP CURRENT BUILD"
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

print_section "5. CLEARING BUILD CACHE"
rm -rf .next/cache 2>/dev/null
rm -rf .next/server 2>/dev/null
rm -rf .next/static 2>/dev/null
print_success "Cleared build cache"

print_section "6. INSTALLING/UPDATING DEPENDENCIES"
echo "This may take a few minutes..."
echo ""

# First, ensure npm is up to date
npm install -g npm@latest 2>/dev/null

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
    echo "Trying to install core packages individually..."
    
    # Install core packages one by one
    npm install next@latest --legacy-peer-deps
    npm install react@latest react-dom@latest --legacy-peer-deps
    npm install --legacy-peer-deps
    
    if [ $? -eq 0 ]; then
        print_success "Core packages installed successfully"
    else
        print_error "Failed to install core packages"
        echo ""
        echo "Manual steps to try:"
        echo "1. cd $APP_DIR"
        echo "2. rm -rf node_modules package-lock.json"
        echo "3. npm cache clean --force"
        echo "4. npm install next react react-dom --legacy-peer-deps"
        echo "5. npm install --legacy-peer-deps"
        exit 1
    fi
fi

print_section "7. VERIFYING NEXT.JS INSTALLATION"

# Check if next is in node_modules
if [ -d "node_modules/next" ]; then
    print_success "Next.js installed in node_modules"
    
    # Get installed version
    if [ -f "node_modules/next/package.json" ]; then
        installed_version=$(grep '"version"' node_modules/next/package.json | head -1 | sed 's/.*"version": "//' | sed 's/".*//')
        print_success "Installed Next.js version: $installed_version"
    fi
else
    print_error "Next.js NOT found in node_modules"
    echo "Installing Next.js explicitly..."
    npm install next@latest --legacy-peer-deps --force
fi

print_section "8. REBUILDING APPLICATION"
echo "Building Next.js application..."
echo ""

# Try to build
npm run build
build_result=$?

if [ $build_result -eq 0 ]; then
    print_success "Build completed successfully"
else
    print_error "Build failed"
    echo ""
    echo "Trying alternative build command..."
    
    # Try direct next build
    npx next build
    build_result=$?
    
    if [ $build_result -eq 0 ]; then
        print_success "Build completed with npx next build"
    else
        print_error "Build still failed"
        echo ""
        echo "Common causes:"
        echo "1. Missing environment variables in .env.local"
        echo "2. Database connection issues"
        echo "3. TypeScript errors in code"
        echo "4. Missing dependencies"
        echo ""
        echo "Check the error messages above for details"
        exit 1
    fi
fi

print_section "9. VERIFYING BUILD OUTPUT"
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

print_section "10. CHECKING ENVIRONMENT CONFIGURATION"
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

print_section "11. FIXING CLOUDFLARE TUNNEL CONFIGURATION"
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

print_section "12. STARTING HOLOVITALS SERVICE"
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

print_section "13. TESTING APPLICATION"
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

print_section "14. RESTARTING CLOUDFLARED"
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

print_section "15. FINAL STATUS CHECK"
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