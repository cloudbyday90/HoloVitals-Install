#!/bin/bash
# HoloVitals Public Installer
# Downloads and installs HoloVitals from private repository

echo "=========================================="
echo "HoloVitals Installer"
echo "=========================================="
echo ""

# Get GitHub PAT
echo "🔑 GitHub Personal Access Token Required"
echo ""
echo "To create a PAT:"
echo "  1. Go to: https://github.com/settings/tokens"
echo "  2. Click 'Generate new token (classic)'"
echo "  3. Name: HoloVitals"
echo "  4. Check: 'repo' (Full control of private repositories)"
echo "  5. Generate and copy the token"
echo ""
echo "⚠️  IMPORTANT: The installer will now wait for you to paste your token."
echo "   After pasting, press ENTER to continue."
echo ""

read -p "Paste your GitHub Personal Access Token and press ENTER: " PAT

if [ -z "$PAT" ]; then
    echo ""
    echo "❌ No token provided"
    echo "Please run the installer again and provide your GitHub PAT."
    exit 1
fi

echo ""
echo "✅ Token received"
echo ""

# Fix Ubuntu 24.04
echo "📦 Installing all prerequisites and dependencies..."
VER=$(lsb_release -rs 2>/dev/null || echo "")
if [[ "$VER" == "24.04" ]]; then
    echo "  → Fixing Ubuntu 24.04 repositories..."
    sudo apt-get clean >/dev/null 2>&1
    sudo rm -rf /var/lib/apt/lists/* >/dev/null 2>&1
    sudo apt-get update --fix-missing >/dev/null 2>&1 || true
    sudo apt-get install -y ca-certificates >/dev/null 2>&1
fi

echo "  → Updating package lists..."
sudo apt-get update >/dev/null 2>&1

echo "  → Installing base packages (git, jq, curl, wget, build-essential)..."
sudo apt-get install -y git jq curl wget build-essential unzip >/dev/null 2>&1

echo "  → Installing Node.js 20.x and npm..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Ensure npm is installed (sometimes needs separate installation)
if ! command -v npm &> /dev/null; then
    echo "  → npm not found, installing separately..."
    sudo apt-get install -y npm
fi

echo "  → Installing PostgreSQL..."
if ! command -v psql &> /dev/null; then
    sudo apt-get install -y postgresql postgresql-contrib >/dev/null 2>&1
fi

echo "✅ All prerequisites installed"
echo "  ✓ Node.js: $(node --version 2>/dev/null || echo 'not found')"
echo "  ✓ npm: $(npm --version 2>/dev/null || echo 'not found')"
echo "  ✓ PostgreSQL: $(psql --version 2>/dev/null | cut -d' ' -f3 || echo 'not found')"
echo ""

# Clone repository
echo "📥 Downloading HoloVitals..."

cd ~
[ -d "HoloVitals" ] && mv HoloVitals "HoloVitals.backup.$(date +%s)"

if git clone "https://${PAT}@github.com/cloudbyday90/HoloVitals.git"; then
    echo "✅ Repository downloaded"
    cd HoloVitals
    git checkout modular-installer-v2
    echo ""
    echo "=========================================="
    echo "Launching HoloVitals Installer"
    echo "=========================================="
    echo ""
    sleep 2
    cd scripts
    ./install-modular.sh
else
    echo "❌ Failed to download repository"
    echo ""
    echo "Please check:"
    echo "  1. Your GitHub PAT is valid"
    echo "  2. Your PAT has 'repo' scope"
    echo "  3. You have access to cloudbyday90/HoloVitals"
    exit 1
fi