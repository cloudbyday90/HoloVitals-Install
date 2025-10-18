#!/bin/bash

# SuperNinja Temporary SSH Access Setup
# Run this script on your server to create temporary access for diagnostics

echo "=================================================="
echo "SuperNinja Temporary SSH Access Setup"
echo "=================================================="
echo ""

# Create temporary diagnostic user
echo "Creating temporary user: superninja_temp..."
sudo adduser --disabled-password --gecos 'SuperNinja Diagnostics' superninja_temp

# Add to sudo group
echo "Adding to sudo group..."
sudo usermod -aG sudo superninja_temp

# Allow sudo without password for this user (temporary)
echo "superninja_temp ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/superninja_temp

# Create SSH directory
echo "Setting up SSH directory..."
sudo mkdir -p /home/superninja_temp/.ssh
sudo chmod 700 /home/superninja_temp/.ssh

# Generate SSH key pair
echo "Generating SSH key pair..."
ssh-keygen -t ed25519 -f /tmp/superninja_key -N "" -C "superninja-temp-access"

# Set up authorized_keys
sudo cp /tmp/superninja_key.pub /home/superninja_temp/.ssh/authorized_keys
sudo chmod 600 /home/superninja_temp/.ssh/authorized_keys
sudo chown -R superninja_temp:superninja_temp /home/superninja_temp/.ssh

echo ""
echo "=================================================="
echo "Setup Complete!"
echo "=================================================="
echo ""

# Display connection information
echo "=== CONNECTION INFORMATION ==="
echo "Username: superninja_temp"
echo "Server IP: $(curl -s ifconfig.me)"
echo ""

# Display the private key
echo "=== PRIVATE SSH KEY (Share this securely) ==="
cat /tmp/superninja_key
echo "=== END PRIVATE KEY ==="
echo ""

# Save to file for easy access
cp /tmp/superninja_key ~/superninja_private_key.txt
chmod 600 ~/superninja_private_key.txt

echo "Private key also saved to: ~/superninja_private_key.txt"
echo ""

# Create removal script
cat > ~/remove_superninja_access.sh << 'EOF'
#!/bin/bash
echo "Removing SuperNinja temporary access..."
sudo deluser --remove-home superninja_temp
sudo rm /etc/sudoers.d/superninja_temp
rm /tmp/superninja_key*
rm ~/superninja_private_key.txt
rm ~/remove_superninja_access.sh
echo "Access removed successfully!"
EOF

chmod +x ~/remove_superninja_access.sh

echo "=================================================="
echo "To remove access later, run:"
echo "bash ~/remove_superninja_access.sh"
echo "=================================================="
echo ""