#!/bin/bash
# HoloVitals Complete All-in-One Installer
# Does everything in one script - no modular complexity

set -e

echo "=========================================="
echo "HoloVitals Complete Installer"
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

read -p "Paste your GitHub Personal Access Token and press ENTER: " GITHUB_PAT

if [ -z "$GITHUB_PAT" ]; then
    echo ""
    echo "❌ No token provided"
    exit 1
fi

echo ""
echo "✅ Token received"
echo ""

# Get Cloudflare Tunnel Token
echo "🔑 Cloudflare Tunnel Token Required"
echo ""
echo "To get your Cloudflare Tunnel token:"
echo "  1. Go to: https://one.dash.cloudflare.com/"
echo "  2. Navigate to Networks > Tunnels"
echo "  3. Create a new tunnel or select existing"
echo "  4. Copy the tunnel token (starts with 'eyJ...')"
echo ""

read -p "Paste your Cloudflare Tunnel Token and press ENTER: " CLOUDFLARE_TOKEN

if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo ""
    echo "❌ No token provided"
    exit 1
fi

echo ""
echo "✅ Cloudflare token received"
echo ""

# Get domain name
read -p "Enter your domain name (e.g., alpha.holovitals.net): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo "❌ No domain provided"
    exit 1
fi

echo ""
echo "✅ Domain: $DOMAIN_NAME"
echo ""

# Fix Ubuntu 24.04
echo "📦 Installing prerequisites..."
VER=$(lsb_release -rs 2>/dev/null || echo "")
if [[ "$VER" == "24.04" ]]; then
    echo "  → Fixing Ubuntu 24.04 repositories..."
    sudo apt-get clean
    sudo rm -rf /var/lib/apt/lists/*
    sudo apt-get update --fix-missing || true
    sudo apt-get install -y ca-certificates
fi

echo "  → Updating package lists..."
sudo apt-get update

echo "  → Installing base packages..."
sudo apt-get install -y curl wget git build-essential jq unzip

echo "  → Installing Node.js 20.x..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "  → Installing PostgreSQL..."
if ! command -v psql &> /dev/null; then
    sudo apt-get install -y postgresql postgresql-contrib
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

echo "✅ Prerequisites installed"
echo ""

# Clone repository
echo "📥 Downloading HoloVitals..."
cd ~
[ -d "HoloVitals" ] && mv HoloVitals "HoloVitals.backup.$(date +%s)"

if ! git clone "https://${GITHUB_PAT}@github.com/cloudbyday90/HoloVitals.git"; then
    echo "❌ Failed to clone repository"
    exit 1
fi

cd HoloVitals
git checkout modular-installer-v2

echo "✅ Repository downloaded"
echo ""

# Setup database
echo "🗄️  Setting up database..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

sudo -u postgres psql -c "CREATE USER holovitals WITH PASSWORD '$DB_PASSWORD';" 2>/dev/null || true
sudo -u postgres psql -c "CREATE DATABASE holovitals OWNER holovitals;" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE holovitals TO holovitals;" 2>/dev/null || true

echo "✅ Database created"
echo ""

# Create .env.local
echo "⚙️  Configuring environment..."
cd ~/HoloVitals/medical-analysis-platform

cat > .env.local << EOF
DATABASE_URL="postgresql://holovitals:${DB_PASSWORD}@localhost:5432/holovitals"
NEXTAUTH_SECRET="$(openssl rand -base64 32)"
NEXTAUTH_URL="https://${DOMAIN_NAME}"
EOF

echo "✅ Environment configured"
echo ""

# Install dependencies
echo "📦 Installing application dependencies..."
npm install

echo "✅ Dependencies installed"
echo ""

# Run migrations
echo "🔄 Running database migrations..."
npx prisma generate
npx prisma migrate deploy

echo "✅ Migrations complete"
echo ""

# Build application
echo "🔨 Building application..."
npm run build

echo "✅ Application built"
echo ""

# Setup Cloudflare Tunnel
echo "🌐 Setting up Cloudflare Tunnel..."

sudo mkdir -p /etc/cloudflared
sudo tee /etc/cloudflared/config.yml > /dev/null << EOF
tunnel: $(echo "$CLOUDFLARE_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.t')
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: ${DOMAIN_NAME}
    service: http://localhost:3000
  - service: http_status:404
EOF

echo "$CLOUDFLARE_TOKEN" | base64 -d > /etc/cloudflared/credentials.json

# Install cloudflared
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
rm cloudflared-linux-amd64.deb

# Create cloudflared service
sudo tee /etc/systemd/system/cloudflared.service > /dev/null << EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/cloudflared tunnel --config /etc/cloudflared/config.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

echo "✅ Cloudflare Tunnel configured"
echo ""

# Create HoloVitals service
echo "🚀 Setting up HoloVitals service..."

sudo tee /etc/systemd/system/holovitals.service > /dev/null << EOF
[Unit]
Description=HoloVitals Application
After=network.target postgresql.service

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/home/$(whoami)/HoloVitals/medical-analysis-platform
Environment="NODE_ENV=production"
ExecStart=/usr/bin/npm start
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable holovitals
sudo systemctl start holovitals

echo "✅ HoloVitals service started"
echo ""

echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Your HoloVitals installation is ready!"
echo ""
echo "🌐 Access your application at: https://${DOMAIN_NAME}"
echo ""
echo "📊 Service Status:"
echo "  • HoloVitals: $(systemctl is-active holovitals)"
echo "  • Cloudflare Tunnel: $(systemctl is-active cloudflared)"
echo "  • PostgreSQL: $(systemctl is-active postgresql)"
echo ""
echo "📝 Useful Commands:"
echo "  • View logs: sudo journalctl -u holovitals -f"
echo "  • Restart: sudo systemctl restart holovitals"
echo "  • Stop: sudo systemctl stop holovitals"
echo ""