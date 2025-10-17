# HoloVitals Secure Access & Connection Error Fix Guide

## Overview
This guide provides multiple secure methods to access your HoloVitals server and fix persistent Cloudflare tunnel connection errors.

## Quick Start - Choose Your Method

### Method 1: Quick Fix (Recommended for Immediate Resolution)
**Best for:** Fixing connection errors quickly with minimal setup

1. Copy `quick-fix-connection-errors.sh` to your server
2. Run: `sudo bash quick-fix-connection-errors.sh`
3. Follow the prompts and provide your tunnel token
4. Monitor the output for success

### Method 2: Diagnostic First Approach
**Best for:** Understanding the root cause before fixing

1. Copy `remote-diagnostics-collector.sh` to your server
2. Run: `bash remote-diagnostics-collector.sh`
3. Share the output file for analysis
4. Apply targeted fixes based on findings

### Method 3: Secure Remote Access
**Best for:** Ongoing management and troubleshooting

1. Review `secure-server-access-guide.sh` for access methods
2. Set up SSH key-based authentication
3. Connect securely to your server
4. Run diagnostic and fix scripts as needed

---

## Detailed Instructions

### Option A: Quick Fix Script (Fastest Solution)

#### What It Does
The `quick-fix-connection-errors.sh` script automatically:
- Locates your HoloVitals installation
- Verifies the application is running on port 3000
- Stops and cleans old cloudflared configurations
- Creates optimized tunnel configuration with QUIC protocol
- Sets up proper credentials from your tunnel token
- Fixes system permissions (ping_group_range)
- Creates and starts a systemd service
- Monitors for connection errors
- Tests domain connectivity

#### Prerequisites
- Root or sudo access to your server
- Your Cloudflare Tunnel Token (from https://one.dash.cloudflare.com/)
- HoloVitals application installed

#### Step-by-Step Instructions

1. **Copy the script to your server:**
   ```bash
   # Option 1: Using scp (from your local machine)
   scp quick-fix-connection-errors.sh username@your-server-ip:/tmp/
   
   # Option 2: Using wget (on your server)
   wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/quick-fix-connection-errors.sh -O /tmp/quick-fix-connection-errors.sh
   
   # Option 3: Manual copy-paste
   # Copy the script content and paste into: nano /tmp/quick-fix-connection-errors.sh
   ```

2. **Make it executable:**
   ```bash
   chmod +x /tmp/quick-fix-connection-errors.sh
   ```

3. **Run the script:**
   ```bash
   sudo bash /tmp/quick-fix-connection-errors.sh
   ```

4. **When prompted, provide your tunnel token:**
   - Go to https://one.dash.cloudflare.com/
   - Navigate to your tunnel
   - Copy the tunnel token
   - Paste it when the script asks

5. **Monitor the output:**
   - The script will show progress for each step
   - Green checkmarks (✓) indicate success
   - Yellow warnings (⚠) indicate non-critical issues
   - Red errors (✗) indicate problems that need attention

6. **Wait for completion:**
   - The script monitors logs for 30 seconds
   - Watch for "registered" or "connected" messages (good signs)
   - Watch for "error" or "failed" messages (problems)

7. **Verify success:**
   - Check if the service is running: `systemctl status cloudflared`
   - Test your domain: `curl -I https://alpha.holovitals.net`
   - View live logs: `journalctl -u cloudflared -f`

#### Expected Output
```
=================================================
HoloVitals Connection Error Quick Fix
=================================================

=================================================
Step 1: Locating HoloVitals Installation
=================================================
✓ Found HoloVitals at: /home/holovitalsdev

=================================================
Step 2: Checking Application Status
=================================================
✓ package.json found
✓ Application is running on port 3000

[... continues through all steps ...]

=================================================
Summary
=================================================

Configuration:
  - Tunnel ID: 573f4a9f-f0aa-4bce-8b78-a54eba1205d7
  - Domain: alpha.holovitals.net
  - Local Service: http://localhost:3000
  - Protocol: QUIC

✓ Setup complete! Monitor logs for any connection errors.
```

#### Troubleshooting Quick Fix

**If the script fails at Step 1 (Finding HoloVitals):**
```bash
# Manually find your installation
find / -type d -name "HoloVitals" 2>/dev/null

# Edit the script to add your path
nano /tmp/quick-fix-connection-errors.sh
# Add your path to the SEARCH_PATHS array
```

**If the script fails at Step 2 (Application not running):**
```bash
# Manually start the application
cd /path/to/HoloVitals
npm install
npm start &

# Then re-run the script
```

**If the script fails at Step 7 (Invalid tunnel token):**
- Verify you copied the complete token
- Check for extra spaces or line breaks
- Get a fresh token from Cloudflare dashboard

**If cloudflared won't start:**
```bash
# Check detailed logs
journalctl -u cloudflared -n 100 --no-pager

# Check configuration
cat /etc/cloudflared/config.yml

# Validate credentials JSON
cat /etc/cloudflared/credentials.json | jq .
```

---

### Option B: Diagnostic Collection (For Analysis)

#### What It Does
The `remote-diagnostics-collector.sh` script collects:
- System information (OS, kernel, uptime)
- HoloVitals installation details
- Application status and processes
- Port 3000 status and connectivity
- Cloudflared configuration and status
- Recent logs (last 100 lines)
- Network configuration
- Firewall settings
- System resources
- Connectivity tests

#### Step-by-Step Instructions

1. **Copy the script to your server:**
   ```bash
   scp remote-diagnostics-collector.sh username@your-server-ip:/tmp/
   ```

2. **Make it executable:**
   ```bash
   chmod +x /tmp/remote-diagnostics-collector.sh
   ```

3. **Run the script:**
   ```bash
   bash /tmp/remote-diagnostics-collector.sh
   ```

4. **Review the output:**
   ```bash
   # View the full diagnostics
   cat holovitals-diagnostics-*.txt
   
   # View the sanitized version (safe to share)
   cat holovitals-diagnostics-sanitized-*.txt
   ```

5. **Share the sanitized file:**
   - Copy the content: `cat holovitals-diagnostics-sanitized-*.txt`
   - Paste into a support ticket or message
   - Or upload to a secure file sharing service

#### What to Look For in Diagnostics

**Good Signs:**
- Application running on port 3000
- Cloudflared service active
- Valid JSON in credentials.json
- No recent errors in logs
- Successful connectivity tests

**Warning Signs:**
- Application not running
- Cloudflared service inactive
- Invalid JSON in credentials
- "accept stream listener" errors
- "context canceled" errors
- Connection timeout errors

---

### Option C: Secure Remote Access Setup

#### SSH Key-Based Authentication (Most Secure)

1. **Generate SSH key pair (on your local machine):**
   ```bash
   ssh-keygen -t ed25519 -C "holovitals-access"
   ```

2. **Copy public key to server:**
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub username@your-server-ip
   ```

3. **Test connection:**
   ```bash
   ssh username@your-server-ip
   ```

4. **Configure SSH for convenience:**
   ```bash
   # Add to ~/.ssh/config
   Host holovitals
       HostName your-server-ip
       User username
       Port 22
       IdentityFile ~/.ssh/id_ed25519
       ServerAliveInterval 60
       ServerAliveCountMax 3
   
   # Now connect with: ssh holovitals
   ```

5. **Disable password authentication (optional but recommended):**
   ```bash
   # On your server
   sudo nano /etc/ssh/sshd_config
   
   # Set these values:
   PasswordAuthentication no
   PubkeyAuthentication yes
   
   # Restart SSH
   sudo systemctl restart sshd
   ```

#### SSH with Port Forwarding (For Local Testing)

```bash
# Forward HoloVitals port to your local machine
ssh -L 3000:localhost:3000 username@your-server-ip

# Now access the app locally at: http://localhost:3000
```

#### Temporary Diagnostic Access (For One-Time Help)

If you need to grant temporary access for troubleshooting:

1. **On your server, run:**
   ```bash
   # Create temporary user
   sudo adduser --disabled-password --gecos 'Temp Diagnostics' temp_diag
   sudo usermod -aG sudo temp_diag
   
   # Generate temporary SSH key
   ssh-keygen -t ed25519 -f /tmp/temp_key -N "" -C "temp-access"
   
   # Set up authorized_keys
   sudo mkdir -p /home/temp_diag/.ssh
   sudo cp /tmp/temp_key.pub /home/temp_diag/.ssh/authorized_keys
   sudo chmod 700 /home/temp_diag/.ssh
   sudo chmod 600 /home/temp_diag/.ssh/authorized_keys
   sudo chown -R temp_diag:temp_diag /home/temp_diag/.ssh
   
   # Display private key (share securely)
   cat /tmp/temp_key
   ```

2. **Share the private key securely** (encrypted message, secure file transfer)

3. **After diagnostics, remove the user:**
   ```bash
   sudo deluser --remove-home temp_diag
   rm /tmp/temp_key*
   ```

---

## Common Connection Errors & Solutions

### Error: "accept stream listener"
**Cause:** Connection timeout or network issues
**Solution:**
- Increase timeout values in config.yml
- Use QUIC protocol instead of HTTP/2
- Check network connectivity to Cloudflare

### Error: "context canceled"
**Cause:** Request timeout or service interruption
**Solution:**
- Verify application is running and responsive
- Check for high CPU/memory usage
- Restart cloudflared service

### Error: "Invalid JSON in credentials.json"
**Cause:** Corrupted credentials file
**Solution:**
- Recreate credentials from tunnel token
- Validate JSON syntax: `cat credentials.json | jq .`
- Ensure proper file permissions (600)

### Error: "GID not within ping_group_range"
**Cause:** System permission issue
**Solution:**
```bash
echo "net.ipv4.ping_group_range = 0 2147483647" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo systemctl restart cloudflared
```

### Error: "tunnel credentials file not found"
**Cause:** Missing or misplaced credentials
**Solution:**
- Check credentials location: `/etc/cloudflared/credentials.json`
- Verify config.yml points to correct path
- Recreate credentials from tunnel token

---

## Monitoring & Maintenance

### View Live Logs
```bash
# Follow cloudflared logs
journalctl -u cloudflared -f

# View last 100 lines
journalctl -u cloudflared -n 100 --no-pager

# View logs with timestamps
journalctl -u cloudflared -f --since "5 minutes ago"
```

### Check Service Status
```bash
# Service status
systemctl status cloudflared

# Is service active?
systemctl is-active cloudflared

# Is service enabled?
systemctl is-enabled cloudflared
```

### Restart Service
```bash
# Restart cloudflared
sudo systemctl restart cloudflared

# Stop and start
sudo systemctl stop cloudflared
sudo systemctl start cloudflared
```

### Test Connectivity
```bash
# Test local application
curl http://localhost:3000

# Test domain
curl -I https://alpha.holovitals.net

# Test with verbose output
curl -v https://alpha.holovitals.net
```

### Monitor System Resources
```bash
# CPU and memory usage
top -bn1 | grep cloudflared

# Detailed process info
ps aux | grep cloudflared

# Network connections
netstat -tlnp | grep cloudflared
```

---

## Security Best Practices

### 1. Use SSH Keys Only
- Never use password authentication for production servers
- Use strong passphrases for SSH keys
- Rotate keys periodically

### 2. Enable Firewall
```bash
# Install and configure UFW
sudo apt install ufw
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
```

### 3. Install Fail2Ban
```bash
# Prevent brute force attacks
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 4. Keep System Updated
```bash
# Regular updates
sudo apt update && sudo apt upgrade -y

# Update cloudflared
sudo cloudflared update
```

### 5. Monitor Logs Regularly
```bash
# Set up log rotation
sudo nano /etc/logrotate.d/cloudflared

# Add:
/var/log/cloudflared.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

### 6. Backup Configuration
```bash
# Regular backups
sudo tar -czf cloudflared-backup-$(date +%Y%m%d).tar.gz /etc/cloudflared/

# Store backups securely off-server
```

---

## Troubleshooting Workflow

### Step 1: Verify Application
```bash
# Is the app running?
ps aux | grep node

# Is port 3000 listening?
netstat -tlnp | grep :3000

# Can we connect locally?
curl http://localhost:3000
```

### Step 2: Check Cloudflared Service
```bash
# Is service running?
systemctl status cloudflared

# Recent logs
journalctl -u cloudflared -n 50
```

### Step 3: Validate Configuration
```bash
# Check config syntax
cat /etc/cloudflared/config.yml

# Validate credentials JSON
cat /etc/cloudflared/credentials.json | jq .
```

### Step 4: Test Connectivity
```bash
# DNS resolution
nslookup alpha.holovitals.net

# Cloudflare connectivity
ping -c 3 1.1.1.1

# Domain accessibility
curl -I https://alpha.holovitals.net
```

### Step 5: Apply Fixes
```bash
# If issues found, run quick fix
sudo bash quick-fix-connection-errors.sh

# Or apply targeted fixes based on diagnostics
```

---

## Getting Help

### Collect Information
Before requesting help, gather:
1. Output from diagnostic script
2. Recent cloudflared logs (last 100 lines)
3. Service status output
4. Any error messages

### Share Safely
- Use the sanitized diagnostics file
- Redact sensitive information (IPs, tokens, secrets)
- Share via secure channels

### Include Context
- What were you doing when the error occurred?
- When did the problem start?
- What have you tried already?
- Any recent changes to the system?

---

## Quick Reference Commands

```bash
# Service Management
sudo systemctl start cloudflared
sudo systemctl stop cloudflared
sudo systemctl restart cloudflared
sudo systemctl status cloudflared

# Logs
journalctl -u cloudflared -f
journalctl -u cloudflared -n 100

# Configuration
cat /etc/cloudflared/config.yml
cat /etc/cloudflared/credentials.json

# Testing
curl http://localhost:3000
curl -I https://alpha.holovitals.net

# Diagnostics
bash remote-diagnostics-collector.sh

# Quick Fix
sudo bash quick-fix-connection-errors.sh
```

---

## Next Steps

1. **Choose your approach:**
   - Quick fix for immediate resolution
   - Diagnostics for understanding issues
   - Secure access for ongoing management

2. **Execute the scripts:**
   - Follow the step-by-step instructions
   - Monitor output for errors
   - Verify success

3. **Monitor and maintain:**
   - Check logs regularly
   - Keep system updated
   - Backup configurations

4. **Get help if needed:**
   - Collect diagnostics
   - Share sanitized information
   - Provide context

---

## Support

For additional help:
- GitHub Issues: https://github.com/cloudbyday90/HoloVitals-Install/issues
- Documentation: Check repository README files
- Cloudflare Docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/

---

**Last Updated:** 2025-10-17
**Version:** 1.0.0