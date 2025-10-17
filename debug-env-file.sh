#!/bin/bash
# Debug script to diagnose .env file issues

echo "=========================================="
echo "HoloVitals .env File Diagnostics"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check 1: State file
echo -e "${BLUE}Check 1: Installation State File${NC}"
STATE_FILE="$HOME/.holovitals-installer/state.json"

if [ -f "$STATE_FILE" ]; then
    echo -e "${GREEN}✓${NC} State file exists: $STATE_FILE"
    echo ""
    echo "State file contents:"
    cat "$STATE_FILE" | jq '.' 2>/dev/null || cat "$STATE_FILE"
    echo ""
    
    # Extract key values
    REPO_DIR=$(jq -r '.repo_dir // empty' "$STATE_FILE" 2>/dev/null)
    BASE_DIR=$(jq -r '.base_dir // empty' "$STATE_FILE" 2>/dev/null)
    DB_NAME=$(jq -r '.db_name // empty' "$STATE_FILE" 2>/dev/null)
    DB_USER=$(jq -r '.db_user // empty' "$STATE_FILE" 2>/dev/null)
    
    echo "Extracted values:"
    echo "  repo_dir: ${REPO_DIR:-'NOT SET'}"
    echo "  base_dir: ${BASE_DIR:-'NOT SET'}"
    echo "  db_name: ${DB_NAME:-'NOT SET'}"
    echo "  db_user: ${DB_USER:-'NOT SET'}"
else
    echo -e "${RED}✗${NC} State file not found: $STATE_FILE"
    REPO_DIR=""
fi

echo ""
echo "=========================================="
echo ""

# Check 2: Repository directory
echo -e "${BLUE}Check 2: Repository Directory${NC}"

# Try multiple possible locations
POSSIBLE_DIRS=(
    "$REPO_DIR"
    "$HOME/HoloVitals"
    "/home/holovitalsdev/HoloVitals"
    "$BASE_DIR/HoloVitals"
)

FOUND_DIR=""
for dir in "${POSSIBLE_DIRS[@]}"; do
    if [ -n "$dir" ] && [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} Found directory: $dir"
        FOUND_DIR="$dir"
        break
    fi
done

if [ -z "$FOUND_DIR" ]; then
    echo -e "${RED}✗${NC} Repository directory not found"
    echo "Searched locations:"
    for dir in "${POSSIBLE_DIRS[@]}"; do
        [ -n "$dir" ] && echo "  - $dir"
    done
else
    echo ""
    echo "Directory contents:"
    ls -la "$FOUND_DIR" | head -20
fi

echo ""
echo "=========================================="
echo ""

# Check 3: .env file
echo -e "${BLUE}Check 3: .env File${NC}"

if [ -n "$FOUND_DIR" ]; then
    ENV_FILE="$FOUND_DIR/.env"
    
    if [ -f "$ENV_FILE" ]; then
        echo -e "${GREEN}✓${NC} .env file exists: $ENV_FILE"
        echo ""
        echo "File permissions:"
        ls -l "$ENV_FILE"
        echo ""
        echo "File contents (sensitive data masked):"
        cat "$ENV_FILE" | sed 's/\(PASSWORD\|SECRET\|KEY\)=.*/\1=***MASKED***/g'
        echo ""
        
        # Check for required variables
        echo "Required variables check:"
        if grep -q "DATABASE_URL" "$ENV_FILE"; then
            echo -e "${GREEN}✓${NC} DATABASE_URL present"
        else
            echo -e "${RED}✗${NC} DATABASE_URL missing"
        fi
        
        if grep -q "NEXTAUTH_SECRET" "$ENV_FILE"; then
            echo -e "${GREEN}✓${NC} NEXTAUTH_SECRET present"
        else
            echo -e "${YELLOW}⚠${NC} NEXTAUTH_SECRET missing (optional)"
        fi
        
        if grep -q "NODE_ENV" "$ENV_FILE"; then
            echo -e "${GREEN}✓${NC} NODE_ENV present"
        else
            echo -e "${YELLOW}⚠${NC} NODE_ENV missing (optional)"
        fi
    else
        echo -e "${RED}✗${NC} .env file not found: $ENV_FILE"
        
        # Check for alternative locations
        echo ""
        echo "Checking alternative locations:"
        ALT_LOCATIONS=(
            "$FOUND_DIR/.env.local"
            "$FOUND_DIR/.env.production"
            "$FOUND_DIR/.env.development"
        )
        
        for alt in "${ALT_LOCATIONS[@]}"; do
            if [ -f "$alt" ]; then
                echo -e "${YELLOW}⚠${NC} Found: $alt"
            fi
        done
    fi
else
    echo -e "${RED}✗${NC} Cannot check .env file (repository directory not found)"
fi

echo ""
echo "=========================================="
echo ""

# Check 4: Prisma setup
echo -e "${BLUE}Check 4: Prisma Setup${NC}"

if [ -n "$FOUND_DIR" ]; then
    cd "$FOUND_DIR"
    
    if [ -d "node_modules" ]; then
        echo -e "${GREEN}✓${NC} node_modules directory exists"
        
        if [ -f "node_modules/.bin/prisma" ]; then
            echo -e "${GREEN}✓${NC} Prisma CLI installed"
            echo "  Version: $(npx prisma --version | head -1)"
        else
            echo -e "${RED}✗${NC} Prisma CLI not found in node_modules"
        fi
    else
        echo -e "${RED}✗${NC} node_modules directory not found"
        echo "  Run: npm install"
    fi
    
    echo ""
    
    if [ -f "prisma/schema.prisma" ]; then
        echo -e "${GREEN}✓${NC} Prisma schema exists"
    else
        echo -e "${RED}✗${NC} Prisma schema not found"
    fi
else
    echo -e "${RED}✗${NC} Cannot check Prisma setup (repository directory not found)"
fi

echo ""
echo "=========================================="
echo ""

# Check 5: Database connection
echo -e "${BLUE}Check 5: Database Connection${NC}"

if command -v psql &> /dev/null; then
    echo -e "${GREEN}✓${NC} PostgreSQL client installed"
    
    # Try to connect to database
    if [ -n "$DB_NAME" ] && [ -n "$DB_USER" ]; then
        echo ""
        echo "Testing database connection..."
        if psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Database connection successful"
        else
            echo -e "${RED}✗${NC} Cannot connect to database"
            echo "  Database: $DB_NAME"
            echo "  User: $DB_USER"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Database credentials not available for testing"
    fi
else
    echo -e "${RED}✗${NC} PostgreSQL client not installed"
fi

echo ""
echo "=========================================="
echo ""

# Summary and recommendations
echo -e "${BLUE}Summary and Recommendations${NC}"
echo ""

if [ -f "$ENV_FILE" ] && grep -q "DATABASE_URL" "$ENV_FILE"; then
    echo -e "${GREEN}✓${NC} .env file is properly configured"
    echo ""
    echo "If Phase 07 is still failing, the issue might be:"
    echo "  1. Phase 07 script not changing to correct directory"
    echo "  2. Phase 07 script using wrong path variable"
    echo "  3. Permissions issue preventing script from reading .env"
    echo ""
    echo "Try running the fix script:"
    echo "  bash fix-phase-07-migration.sh"
else
    echo -e "${RED}✗${NC} .env file is missing or incomplete"
    echo ""
    echo "To fix this issue:"
    echo "  1. Run the fix script: bash fix-phase-07-migration.sh"
    echo "  2. Or manually create .env file in: $FOUND_DIR/.env"
    echo ""
    echo "The .env file should contain:"
    echo "  DATABASE_URL=&quot;postgresql://USER:PASSWORD@localhost:5432/DATABASE?schema=public&quot;"
    echo "  NEXTAUTH_SECRET=&quot;your-secret-here&quot;"
    echo "  NODE_ENV=&quot;production&quot;"
fi

echo ""
echo "=========================================="