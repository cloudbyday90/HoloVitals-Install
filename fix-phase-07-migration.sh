#!/bin/bash
# Fix Script for Phase 07 Migration Error
# This script fixes the ".env file not found" error
# UPDATED: Addresses the REAL root cause (subdirectory + .env.local)

set -e

echo "=========================================="
echo "Phase 07 Migration Error Fix"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load state file
STATE_FILE="$HOME/.holovitals-installer/state.json"

if [ ! -f "$STATE_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} State file not found: $STATE_FILE"
    echo "This script must be run after the installer has started."
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Loading installation state..."

# Extract repository directory from state
REPO_DIR=$(jq -r '.repo_dir // empty' "$STATE_FILE")
BASE_DIR=$(jq -r '.base_dir // empty' "$STATE_FILE")

# Fallback to common locations if not in state
if [ -z "$REPO_DIR" ]; then
    if [ -d "$HOME/HoloVitals" ]; then
        REPO_DIR="$HOME/HoloVitals"
        echo -e "${YELLOW}[WARNING]${NC} repo_dir not in state, using: $REPO_DIR"
    else
        echo -e "${RED}[ERROR]${NC} Cannot find HoloVitals repository directory"
        echo "Please specify the directory manually:"
        read -p "Enter HoloVitals directory path: " REPO_DIR
        
        if [ ! -d "$REPO_DIR" ]; then
            echo -e "${RED}[ERROR]${NC} Directory does not exist: $REPO_DIR"
            exit 1
        fi
    fi
fi

echo -e "${GREEN}[SUCCESS]${NC} Repository directory: $REPO_DIR"
echo ""

# CRITICAL: Change to medical-analysis-platform subdirectory
APP_DIR="$REPO_DIR/medical-analysis-platform"

if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}[ERROR]${NC} Application directory not found: $APP_DIR"
    echo "The repository structure may have changed."
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Application directory: $APP_DIR"
echo ""

# Check if .env.local file exists (NOT .env)
echo -e "${BLUE}[INFO]${NC} Checking for .env.local file..."

ENV_FILE="$APP_DIR/.env.local"

if [ -f "$ENV_FILE" ]; then
    echo -e "${GREEN}[SUCCESS]${NC} .env.local file found: $ENV_FILE"
    
    # Verify it has DATABASE_URL
    if grep -q "DATABASE_URL" "$ENV_FILE"; then
        echo -e "${GREEN}[SUCCESS]${NC} DATABASE_URL found in .env.local"
    else
        echo -e "${RED}[ERROR]${NC} DATABASE_URL not found in .env.local"
        echo "The .env.local file exists but is missing DATABASE_URL"
        exit 1
    fi
else
    echo -e "${RED}[ERROR]${NC} .env.local file not found: $ENV_FILE"
    echo ""
    echo "Attempting to recreate .env.local file..."
    
    # Try to load database credentials from state
    DB_NAME=$(jq -r '.db_name // "holovitals"' "$STATE_FILE")
    DB_USER=$(jq -r '.db_user // "holovitals"' "$STATE_FILE")
    DB_PASSWORD=$(jq -r '.db_password // empty' "$STATE_FILE")
    DOMAIN_NAME=$(jq -r '.domain_name // "localhost"' "$STATE_FILE")
    NEXTAUTH_SECRET=$(jq -r '.nextauth_secret // empty' "$STATE_FILE")
    
    if [ -z "$DB_PASSWORD" ]; then
        echo -e "${RED}[ERROR]${NC} Database password not found in state"
        echo "Please enter the database password:"
        read -s -p "Database password: " DB_PASSWORD
        echo ""
    fi
    
    if [ -z "$NEXTAUTH_SECRET" ]; then
        NEXTAUTH_SECRET=$(openssl rand -base64 32)
    fi
    
    # Create .env.local file
    cat > "$ENV_FILE" << EOF
# Database Configuration
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost:5432/${DB_NAME}"

# NextAuth Configuration
NEXTAUTH_URL="https://${DOMAIN_NAME}"
NEXTAUTH_SECRET="${NEXTAUTH_SECRET}"

# Application
NODE_ENV="production"
NEXT_PUBLIC_APP_URL="https://${DOMAIN_NAME}"
EOF
    
    chmod 600 "$ENV_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} .env.local file created: $ENV_FILE"
fi

echo ""
echo -e "${BLUE}[INFO]${NC} Running database migration..."
echo ""

# Change to application directory
cd "$APP_DIR"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}[WARNING]${NC} node_modules not found, running npm install..."
    npm install
fi

# Check if Prisma is available
if [ ! -f "node_modules/.bin/prisma" ]; then
    echo -e "${RED}[ERROR]${NC} Prisma not found in node_modules"
    echo "Installing Prisma..."
    npm install prisma @prisma/client
fi

# Generate Prisma Client
echo -e "${BLUE}[INFO]${NC} Generating Prisma Client..."
npx prisma generate

# Run migrations using db push (as per original Phase 07 script)
echo -e "${BLUE}[INFO]${NC} Running database migrations..."
npx prisma db push

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}[SUCCESS]${NC} Database migration completed successfully!"
    echo ""
    echo "You can now continue with the installation."
    echo "If the installer is still waiting, choose option 2 (Pull latest updates and retry)"
    exit 0
else
    echo ""
    echo -e "${RED}[ERROR]${NC} Database migration failed"
    echo ""
    echo "Please check:"
    echo "  1. PostgreSQL is running: sudo systemctl status postgresql"
    echo "  2. Database exists: sudo -u postgres psql -l | grep holovitals"
    echo "  3. Database connection works: psql -U holovitals -d holovitals -c 'SELECT 1;'"
    exit 1
fi