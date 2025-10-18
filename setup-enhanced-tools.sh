#!/bin/bash

# Setup script for enhanced error analysis tools
# Run this on your server: bash setup-enhanced-tools.sh

echo "=================================================="
echo "HoloVitals Enhanced Tools Setup"
echo "=================================================="
echo ""

# Create tools directory
TOOLS_DIR="$HOME/holovitals-tools"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"

echo "Downloading enhanced tools..."
echo ""

# Download all tools
echo "1. Downloading quick-fix-connection-errors.sh..."
wget -q https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/secure-access-and-advanced-fixes/quick-fix-connection-errors.sh

echo "2. Downloading remote-diagnostics-collector-v2.sh..."
wget -q https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/secure-access-and-advanced-fixes/remote-diagnostics-collector-v2.sh

echo "3. Downloading enhanced-error-analyzer.sh..."
wget -q https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/secure-access-and-advanced-fixes/enhanced-error-analyzer.sh

echo ""
echo "Making scripts executable..."
chmod +x *.sh

echo ""
echo "✓ Setup complete!"
echo ""
echo "Tools installed in: $TOOLS_DIR"
echo ""
echo "Available commands:"
echo "  1. Quick fix:        sudo bash $TOOLS_DIR/quick-fix-connection-errors.sh"
echo "  2. Diagnostics v2:   bash $TOOLS_DIR/remote-diagnostics-collector-v2.sh"
echo "  3. Error analyzer:   bash $TOOLS_DIR/enhanced-error-analyzer.sh"
echo ""
echo "Recommended: Start with diagnostics to see what's wrong"
echo "  cd $TOOLS_DIR"
echo "  bash remote-diagnostics-collector-v2.sh"
echo ""