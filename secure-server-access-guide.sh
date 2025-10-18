#!/bin/bash

# HoloVitals Secure Server Access Setup
# This script helps establish secure connections to your server

set -e

echo "=================================================="
echo "HoloVitals Secure Server Access Setup"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_section() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Method 1: SSH Key-Based Authentication (Most Secure)
print_section "Method 1: SSH Key-Based Authentication (Recommended)"
echo ""
echo "This is the most secure method for server access."
echo ""
echo "Steps to set up:"
echo "1. Generate SSH key pair (if you don't have one):"
echo "   ssh-keygen -t ed25519 -C 'holovitals-access'"
echo ""
echo "2. Copy your public key to the server:"
echo "   ssh-copy-id -i ~/.ssh/id_ed25519.pub username@your-server-ip"
echo ""
echo "3. Connect to your server:"
echo "   ssh username@your-server-ip"
echo ""
echo "4. For extra security, disable password authentication:"
echo "   sudo nano /etc/ssh/sshd_config"
echo "   Set: PasswordAuthentication no"
echo "   sudo systemctl restart sshd"
echo ""

# Method 2: SSH with Port Forwarding for Diagnostics
print_section "Method 2: SSH with Port Forwarding"
echo ""
echo "This allows secure access to services running on your server."
echo ""
echo "Connect with port forwarding:"
echo "ssh -L 3000:localhost:3000 -L 8080:localhost:8080 username@your-server-ip"
echo ""
echo "This forwards:"
echo "  - Port 3000 (HoloVitals app) to your local machine"
echo "  - Port 8080 (if needed for diagnostics)"
echo ""

# Method 3: Temporary SSH Tunnel for Diagnostics
print_section "Method 3: Temporary Diagnostic Access"
echo ""
echo "For one-time diagnostic access, you can create a temporary user:"
echo ""
echo "On your server, run:"
echo "sudo adduser --disabled-password --gecos '' diagnostics"
echo "sudo usermod -aG sudo diagnostics"
echo "sudo mkdir -p /home/diagnostics/.ssh"
echo "sudo chmod 700 /home/diagnostics/.ssh"
echo ""
echo "Then add a temporary SSH key (expires after use):"
echo "echo 'YOUR_TEMPORARY_PUBLIC_KEY' | sudo tee /home/diagnostics/.ssh/authorized_keys"
echo "sudo chmod 600 /home/diagnostics/.ssh/authorized_keys"
echo "sudo chown -R diagnostics:diagnostics /home/diagnostics/.ssh"
echo ""
echo "After diagnostics, remove the user:"
echo "sudo deluser --remove-home diagnostics"
echo ""

# Method 4: Bastion Host / Jump Server
print_section "Method 4: Bastion Host (For Production Environments)"
echo ""
echo "If your server is in a private network, use a bastion host:"
echo ""
echo "ssh -J bastion-user@bastion-ip username@private-server-ip"
echo ""
echo "Or configure in ~/.ssh/config:"
echo "Host holovitals-server"
echo "    HostName private-server-ip"
echo "    User username"
echo "    ProxyJump bastion-user@bastion-ip"
echo ""

# Method 5: VPN Access
print_section "Method 5: VPN Access (Enterprise Solution)"
echo ""
echo "For the most secure production environment:"
echo "1. Set up WireGuard VPN on your server"
echo "2. Connect to VPN before accessing server"
echo "3. Access server through private network"
echo ""
echo "WireGuard setup:"
echo "sudo apt install wireguard"
echo "wg genkey | tee privatekey | wg pubkey > publickey"
echo ""

# Security Best Practices
print_section "Security Best Practices"
echo ""
echo "1. Always use SSH keys instead of passwords"
echo "2. Change default SSH port (optional but recommended):"
echo "   Edit /etc/ssh/sshd_config: Port 2222"
echo ""
echo "3. Enable firewall:"
echo "   sudo ufw allow 2222/tcp  # or your SSH port"
echo "   sudo ufw allow 80/tcp"
echo "   sudo ufw allow 443/tcp"
echo "   sudo ufw enable"
echo ""
echo "4. Install fail2ban to prevent brute force:"
echo "   sudo apt install fail2ban"
echo "   sudo systemctl enable fail2ban"
echo ""
echo "5. Keep system updated:"
echo "   sudo apt update && sudo apt upgrade -y"
echo ""
echo "6. Use sudo instead of root login"
echo "   Disable root login in /etc/ssh/sshd_config:"
echo "   PermitRootLogin no"
echo ""

# Generate temporary diagnostic script
print_section "Creating Diagnostic Access Script"
echo ""

cat > /tmp/setup-diagnostic-access.sh << 'DIAGNOSTIC_EOF'
#!/bin/bash
# Run this on your server to set up temporary diagnostic access

echo "Setting up temporary diagnostic access..."

# Create temporary user
sudo adduser --disabled-password --gecos 'Temporary Diagnostics' temp_diagnostics

# Add to sudo group
sudo usermod -aG sudo temp_diagnostics

# Create SSH directory
sudo mkdir -p /home/temp_diagnostics/.ssh
sudo chmod 700 /home/temp_diagnostics/.ssh

# Generate temporary SSH key pair
ssh-keygen -t ed25519 -f /tmp/temp_diag_key -N "" -C "temporary-diagnostics"

# Set up authorized_keys
sudo cp /tmp/temp_diag_key.pub /home/temp_diagnostics/.ssh/authorized_keys
sudo chmod 600 /home/temp_diagnostics/.ssh/authorized_keys
sudo chown -R temp_diagnostics:temp_diagnostics /home/temp_diagnostics/.ssh

echo ""
echo "Temporary access created!"
echo "Private key location: /tmp/temp_diag_key"
echo ""
echo "To connect:"
echo "ssh -i /tmp/temp_diag_key temp_diagnostics@YOUR_SERVER_IP"
echo ""
echo "IMPORTANT: After diagnostics, remove this user:"
echo "sudo deluser --remove-home temp_diagnostics"
echo "rm /tmp/temp_diag_key*"
DIAGNOSTIC_EOF

chmod +x /tmp/setup-diagnostic-access.sh

print_success "Diagnostic access script created: /tmp/setup-diagnostic-access.sh"
echo ""

# Create SSH config template
print_section "Creating SSH Config Template"
echo ""

cat > /tmp/ssh-config-template << 'SSH_CONFIG_EOF'
# Add this to your ~/.ssh/config file

Host holovitals
    HostName YOUR_SERVER_IP
    User YOUR_USERNAME
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    
    # For port forwarding (uncomment if needed)
    # LocalForward 3000 localhost:3000
    # LocalForward 8080 localhost:8080

Host holovitals-tunnel
    HostName YOUR_SERVER_IP
    User YOUR_USERNAME
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    LocalForward 3000 localhost:3000
    LocalForward 8080 localhost:8080
    DynamicForward 1080
SSH_CONFIG_EOF

print_success "SSH config template created: /tmp/ssh-config-template"
echo ""

# Summary
print_section "Summary & Next Steps"
echo ""
echo "Choose the best method for your situation:"
echo ""
echo "1. ${GREEN}For regular access:${NC} Use SSH key-based authentication (Method 1)"
echo "2. ${GREEN}For diagnostics:${NC} Use SSH with port forwarding (Method 2)"
echo "3. ${GREEN}For one-time help:${NC} Use temporary diagnostic access (Method 3)"
echo "4. ${GREEN}For production:${NC} Use bastion host or VPN (Methods 4-5)"
echo ""
echo "Files created:"
echo "  - /tmp/setup-diagnostic-access.sh (run on your server)"
echo "  - /tmp/ssh-config-template (add to ~/.ssh/config)"
echo ""
print_warning "Remember: Never share private keys or passwords!"
echo ""

# Offer to create a connection test script
print_section "Would you like to test your connection?"
echo ""
echo "After setting up access, you can test with:"
echo "ssh -v username@your-server-ip 'echo Connection successful!'"
echo ""

print_success "Setup guide complete!"
echo ""
echo "=================================================="