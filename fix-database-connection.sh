#!/bin/bash
# Fix Database Connection Issue for HoloVitals

echo "=========================================="
echo "HoloVitals Database Connection Fix"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR]${NC} Please do not run as root"
    echo "Run as your regular user (the script will use sudo when needed)"
    exit 1
fi

# Load state file
STATE_FILE="$HOME/.holovitals-installer/state.json"

if [ ! -f "$STATE_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} State file not found: $STATE_FILE"
    echo "This script must be run after the installer has started."
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Loading installation state..."

# Get database credentials
DB_NAME=$(jq -r '.db_name // "holovitals"' "$STATE_FILE")
DB_USER=$(jq -r '.db_user // "holovitals"' "$STATE_FILE")
DB_PASSWORD=$(jq -r '.db_password // empty' "$STATE_FILE")

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${RED}[ERROR]${NC} Database password not found in state"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Database credentials loaded"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""

# Check PostgreSQL version
echo -e "${BLUE}[INFO]${NC} Detecting PostgreSQL version..."
PG_VERSION=$(psql --version 2>/dev/null | grep -oP '\d+' | head -1)

if [ -z "$PG_VERSION" ]; then
    echo -e "${RED}[ERROR]${NC} PostgreSQL not found"
    echo "Please install PostgreSQL first"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} PostgreSQL version: $PG_VERSION"
echo ""

# Check if PostgreSQL is running
echo -e "${BLUE}[INFO]${NC} Checking PostgreSQL service..."
if sudo systemctl is-active --quiet postgresql; then
    echo -e "${GREEN}[SUCCESS]${NC} PostgreSQL is running"
else
    echo -e "${YELLOW}[WARNING]${NC} PostgreSQL is not running"
    echo "Starting PostgreSQL..."
    sudo systemctl start postgresql
    sleep 2
    
    if sudo systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}[SUCCESS]${NC} PostgreSQL started"
    else
        echo -e "${RED}[ERROR]${NC} Failed to start PostgreSQL"
        exit 1
    fi
fi
echo ""

# Check if database exists
echo -e "${BLUE}[INFO]${NC} Checking if database exists..."
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    echo -e "${GREEN}[SUCCESS]${NC} Database '$DB_NAME' exists"
else
    echo -e "${RED}[ERROR]${NC} Database '$DB_NAME' does not exist"
    echo "Creating database..."
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    echo -e "${GREEN}[SUCCESS]${NC} Database created"
fi
echo ""

# Check if user exists
echo -e "${BLUE}[INFO]${NC} Checking if database user exists..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    echo -e "${GREEN}[SUCCESS]${NC} User '$DB_USER' exists"
else
    echo -e "${RED}[ERROR]${NC} User '$DB_USER' does not exist"
    echo "Creating user..."
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    echo -e "${GREEN}[SUCCESS]${NC} User created"
fi
echo ""

# Fix pg_hba.conf
echo -e "${BLUE}[INFO]${NC} Checking pg_hba.conf authentication..."
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

if [ ! -f "$PG_HBA" ]; then
    echo -e "${RED}[ERROR]${NC} pg_hba.conf not found at $PG_HBA"
    exit 1
fi

echo -e "${GREEN}[SUCCESS]${NC} Found pg_hba.conf"

# Check if authentication rules exist
if sudo grep -q "^local.*$DB_NAME.*$DB_USER.*md5" "$PG_HBA"; then
    echo -e "${GREEN}[SUCCESS]${NC} Authentication rules already exist"
else
    echo -e "${YELLOW}[WARNING]${NC} Authentication rules not found"
    echo "Adding authentication rules..."
    
    # Backup pg_hba.conf
    sudo cp "$PG_HBA" "$PG_HBA.backup.$(date +%Y%m%d-%H%M%S)"
    
    # Add authentication rules
    sudo bash -c "cat >> $PG_HBA << 'EOF'

# HoloVitals authentication (added by fix script)
local   $DB_NAME      $DB_USER                              md5
host    $DB_NAME      $DB_USER      127.0.0.1/32            md5
host    $DB_NAME      $DB_USER      ::1/128                 md5
EOF"
    
    echo -e "${GREEN}[SUCCESS]${NC} Authentication rules added"
    
    # Reload PostgreSQL
    echo "Reloading PostgreSQL..."
    sudo systemctl reload postgresql
    sleep 2
    echo -e "${GREEN}[SUCCESS]${NC} PostgreSQL reloaded"
fi
echo ""

# Test connection
echo -e "${BLUE}[INFO]${NC} Testing database connection..."
if PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}[SUCCESS]${NC} Database connection successful!"
    echo ""
    echo "You can now continue with the installation."
    echo "If the installer is still waiting, choose option 2 (Pull latest updates and retry)"
    exit 0
else
    echo -e "${RED}[ERROR]${NC} Database connection still failing"
    echo ""
    echo "Additional troubleshooting:"
    echo ""
    echo "1. Check PostgreSQL logs:"
    echo "   sudo tail -50 /var/log/postgresql/postgresql-$PG_VERSION-main.log"
    echo ""
    echo "2. Check pg_hba.conf:"
    echo "   sudo cat $PG_HBA | grep $DB_NAME"
    echo ""
    echo "3. Try manual connection:"
    echo "   PGPASSWORD='$DB_PASSWORD' psql -h localhost -U $DB_USER -d $DB_NAME"
    echo ""
    echo "4. Check PostgreSQL status:"
    echo "   sudo systemctl status postgresql"
    exit 1
fi