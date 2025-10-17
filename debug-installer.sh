#!/bin/bash
# Comprehensive Debug Script for HoloVitals Installer

echo "=========================================="
echo "HoloVitals Installer - Debug Diagnostics"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if state file exists
STATE_FILE="$HOME/.holovitals-installer/state.json"

echo -e "${BLUE}=== System Information ===${NC}"
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Home: $HOME"
echo "Working Directory: $(pwd)"
echo ""

if [ ! -f "$STATE_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} State file not found: $STATE_FILE"
    echo "The installer has not been run yet or state was deleted."
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} State file found: $STATE_FILE"
echo ""

# Load and display state
echo -e "${BLUE}=== Installation State ===${NC}"
cat "$STATE_FILE" | jq '.' 2>/dev/null || cat "$STATE_FILE"
echo ""

# Extract key values
MODE=$(jq -r '.mode // "unknown"' "$STATE_FILE")
REPO_DIR=$(jq -r '.repo_dir // empty' "$STATE_FILE")
BASE_DIR=$(jq -r '.base_dir // empty' "$STATE_FILE")
DB_NAME=$(jq -r '.db_name // "holovitals"' "$STATE_FILE")
DB_USER=$(jq -r '.db_user // "holovitals"' "$STATE_FILE")
DB_PASSWORD=$(jq -r '.db_password // empty' "$STATE_FILE")

echo -e "${BLUE}=== Configuration ===${NC}"
echo "Mode: $MODE"
echo "Repo Dir: ${REPO_DIR:-'NOT SET'}"
echo "Base Dir: ${BASE_DIR:-'NOT SET'}"
echo "DB Name: $DB_NAME"
echo "DB User: $DB_USER"
echo "DB Password: ${DB_PASSWORD:+***SET***}"
echo ""

# Check repository directory
echo -e "${BLUE}=== Repository Check ===${NC}"

if [ -z "$REPO_DIR" ]; then
    REPO_DIR="$BASE_DIR"
fi

if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ]; then
    echo -e "${GREEN}✓${NC} Repository directory exists: $REPO_DIR"
    
    # Check if it's a git repo
    if [ -d "$REPO_DIR/.git" ]; then
        echo -e "${GREEN}✓${NC} Is a git repository"
        cd "$REPO_DIR"
        BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        echo "  Current branch: $BRANCH"
        COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
        echo "  Current commit: $COMMIT"
    else
        echo -e "${YELLOW}⚠${NC} Not a git repository"
    fi
    
    # Check medical-analysis-platform subdirectory
    APP_DIR="$REPO_DIR/medical-analysis-platform"
    if [ -d "$APP_DIR" ]; then
        echo -e "${GREEN}✓${NC} Application directory exists: $APP_DIR"
    else
        echo -e "${RED}✗${NC} Application directory NOT found: $APP_DIR"
    fi
else
    echo -e "${RED}✗${NC} Repository directory not found: $REPO_DIR"
fi
echo ""

# Check environment files
echo -e "${BLUE}=== Environment Files ===${NC}"

if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ]; then
    # Check root directory
    if [ -f "$REPO_DIR/.env" ]; then
        echo -e "${GREEN}✓${NC} Found .env in root: $REPO_DIR/.env"
    else
        echo -e "${YELLOW}⚠${NC} No .env in root directory"
    fi
    
    if [ -f "$REPO_DIR/.env.local" ]; then
        echo -e "${GREEN}✓${NC} Found .env.local in root: $REPO_DIR/.env.local"
    else
        echo -e "${YELLOW}⚠${NC} No .env.local in root directory"
    fi
    
    # Check application directory
    APP_DIR="$REPO_DIR/medical-analysis-platform"
    if [ -d "$APP_DIR" ]; then
        if [ -f "$APP_DIR/.env" ]; then
            echo -e "${GREEN}✓${NC} Found .env in app dir: $APP_DIR/.env"
            echo "  Contents (sensitive data masked):"
            cat "$APP_DIR/.env" | sed 's/\(PASSWORD\|SECRET\|KEY\)=.*/\1=***MASKED***/' | sed 's/^/    /'
        else
            echo -e "${YELLOW}⚠${NC} No .env in application directory"
        fi
        
        if [ -f "$APP_DIR/.env.local" ]; then
            echo -e "${GREEN}✓${NC} Found .env.local in app dir: $APP_DIR/.env.local"
            echo "  Contents (sensitive data masked):"
            cat "$APP_DIR/.env.local" | sed 's/\(PASSWORD\|SECRET\|KEY\)=.*/\1=***MASKED***/' | sed 's/^/    /'
        else
            echo -e "${RED}✗${NC} No .env.local in application directory"
            echo -e "${YELLOW}  This is likely causing Phase 07/08 failures!${NC}"
        fi
    fi
fi
echo ""

# Check PostgreSQL
echo -e "${BLUE}=== PostgreSQL Check ===${NC}"

if command -v psql &> /dev/null; then
    echo -e "${GREEN}✓${NC} PostgreSQL client installed"
    PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
    echo "  Version: $PG_VERSION"
    
    # Check service
    if systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}✓${NC} PostgreSQL service is running"
    else
        echo -e "${RED}✗${NC} PostgreSQL service is NOT running"
    fi
    
    # Check database
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo -e "${GREEN}✓${NC} Database '$DB_NAME' exists"
    else
        echo -e "${RED}✗${NC} Database '$DB_NAME' does NOT exist"
    fi
    
    # Check user
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
        echo -e "${GREEN}✓${NC} User '$DB_USER' exists"
    else
        echo -e "${RED}✗${NC} User '$DB_USER' does NOT exist"
    fi
    
    # Test connection
    if [ -n "$DB_PASSWORD" ]; then
        if PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Can connect to database"
        else
            echo -e "${RED}✗${NC} Cannot connect to database"
            echo -e "${YELLOW}  Check pg_hba.conf authentication rules${NC}"
        fi
    fi
else
    echo -e "${RED}✗${NC} PostgreSQL client not installed"
fi
echo ""

# Check Node.js and npm
echo -e "${BLUE}=== Node.js Check ===${NC}"

if command -v node &> /dev/null; then
    echo -e "${GREEN}✓${NC} Node.js installed: $(node --version)"
else
    echo -e "${RED}✗${NC} Node.js not installed"
fi

if command -v npm &> /dev/null; then
    echo -e "${GREEN}✓${NC} npm installed: $(npm --version)"
else
    echo -e "${RED}✗${NC} npm not installed"
fi

# Check node_modules
if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR/medical-analysis-platform" ]; then
    APP_DIR="$REPO_DIR/medical-analysis-platform"
    if [ -d "$APP_DIR/node_modules" ]; then
        echo -e "${GREEN}✓${NC} node_modules exists in application directory"
        
        # Check Prisma
        if [ -f "$APP_DIR/node_modules/.bin/prisma" ]; then
            echo -e "${GREEN}✓${NC} Prisma CLI installed"
        else
            echo -e "${RED}✗${NC} Prisma CLI not found"
        fi
        
        if [ -d "$APP_DIR/node_modules/@prisma/client" ]; then
            echo -e "${GREEN}✓${NC} Prisma Client installed"
        else
            echo -e "${RED}✗${NC} Prisma Client not found"
        fi
    else
        echo -e "${RED}✗${NC} node_modules not found in application directory"
    fi
fi
echo ""

# Check completed phases
echo -e "${BLUE}=== Completed Phases ===${NC}"
COMPLETED=$(jq -r '.completed_phases // [] | .[]' "$STATE_FILE" 2>/dev/null)
if [ -n "$COMPLETED" ]; then
    echo "$COMPLETED" | while read phase; do
        echo -e "${GREEN}✓${NC} $phase"
    done
else
    echo "No phases completed yet"
fi
echo ""

# Recommendations
echo -e "${BLUE}=== Recommendations ===${NC}"

# Check for common issues
ISSUES_FOUND=false

if [ ! -f "$APP_DIR/.env.local" ] && [ -d "$APP_DIR" ]; then
    echo -e "${YELLOW}⚠${NC} Missing .env.local in application directory"
    echo "  This will cause Phase 07 and Phase 08 to fail"
    echo "  Fix: Run fix-phase-07-migration.sh"
    ISSUES_FOUND=true
fi

if ! PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Cannot connect to database"
    echo "  This will cause Phase 03 verification to fail"
    echo "  Fix: Run fix-database-connection.sh"
    ISSUES_FOUND=true
fi

if [ "$ISSUES_FOUND" = false ]; then
    echo -e "${GREEN}✓${NC} No obvious issues detected"
fi

echo ""
echo -e "${BLUE}=== Available Fix Scripts ===${NC}"
echo "1. fix-database-connection.sh - Fixes PostgreSQL connection issues"
echo "2. fix-phase-07-migration.sh - Fixes Phase 07 .env file issues"
echo "3. debug-env-file.sh - Detailed .env file diagnostics"
echo ""
echo "Download from:"
echo "  wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/[script-name]"
echo ""
echo "=========================================="
echo "Debug diagnostics complete"
echo "=========================================="