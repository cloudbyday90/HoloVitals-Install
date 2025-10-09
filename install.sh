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

read -sp "Paste your GitHub Personal Access Token: " PAT
echo ""
echo ""

if [ -z "$PAT" ]; then
    echo "❌ No token provided"
    exit 1
fi

echo "✅ Token received"
echo ""

# Fix Ubuntu 24.04
echo "📦 Installing prerequisites..."
VER=$(lsb_release -rs 2>/dev/null || echo "")
if [[ "$VER" == "24.04" ]]; then
    echo "  → Fixing Ubuntu 24.04 repositories..."
    sudo apt-get clean >/dev/null 2>&1
    sudo rm -rf /var/lib/apt/lists/* >/dev/null 2>&1
    sudo apt-get update --fix-missing >/dev/null 2>&1 || true
    sudo apt-get install -y ca-certificates >/dev/null 2>&1
fi

sudo apt-get update >/dev/null 2>&1
sudo apt-get install -y git jq >/dev/null 2>&1

echo "✅ Prerequisites installed"
echo ""

# Clone repository
echo "📥 Downloading HoloVitals..."

cd ~
[ -d "HoloVitals" ] && mv HoloVitals "HoloVitals.backup.$(date +%s)"

if git clone "https://${PAT}@github.com/cloudbyday90/HoloVitals.git" 2>&1 | grep -q "Cloning"; then
    echo "✅ Repository downloaded"
    cd HoloVitals
    git checkout modular-installer-v2 >/dev/null 2>&1
    echo ""
    echo "=========================================="
    echo "Launching HoloVitals Installer"
    echo "=========================================="
    echo ""
    sleep 1
    cd scripts
    exec ./install-modular.sh
else
    echo "❌ Failed to download repository"
    echo ""
    echo "Please check:"
    echo "  1. Your GitHub PAT is valid"
    echo "  2. Your PAT has 'repo' scope"
    echo "  3. You have access to cloudbyday90/HoloVitals"
    exit 1
fi