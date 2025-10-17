#!/bin/bash

# HoloVitals Remote Diagnostics Collector
# Run this script on your server to collect diagnostic information
# Then share the output file with support for analysis

set -e

OUTPUT_FILE="holovitals-diagnostics-$(date +%Y%m%d-%H%M%S).txt"

echo "=================================================="
echo "HoloVitals Remote Diagnostics Collector"
echo "=================================================="
echo ""
echo "Collecting diagnostic information..."
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

# Start output file
{
    echo "HoloVitals Diagnostics Report"
    echo "Generated: $(date)"
    echo "=================================================="
    echo ""

    # System Information
    echo "=== SYSTEM INFORMATION ==="
    echo "Hostname: $(hostname)"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime)"
    echo ""

    # Check if running as root/sudo
    echo "=== USER INFORMATION ==="
    echo "Current user: $(whoami)"
    echo "User groups: $(groups)"
    echo ""

    # Find HoloVitals installation
    echo "=== HOLOVITALS INSTALLATION ==="
    HOLOVITALS_DIRS=(
        "/opt/HoloVitals"
        "/home/*/HoloVitals"
        "/home/holovitalsdev"
        "/var/www/HoloVitals"
    )
    
    FOUND_DIR=""
    for dir in "${HOLOVITALS_DIRS[@]}"; do
        if [ -d "$dir" ] 2>/dev/null; then
            FOUND_DIR=$(echo $dir)
            echo "Found HoloVitals at: $FOUND_DIR"
            break
        fi
    done
    
    if [ -z "$FOUND_DIR" ]; then
        echo "WARNING: HoloVitals directory not found in standard locations"
        echo "Searching entire system..."
        find / -type d -name "HoloVitals" 2>/dev/null | head -5
    fi
    echo ""

    # Application Status
    echo "=== APPLICATION STATUS ==="
    if [ -n "$FOUND_DIR" ]; then
        echo "Directory contents:"
        ls -la "$FOUND_DIR" 2>/dev/null || echo "Cannot list directory"
        echo ""
        
        echo "Package.json exists:"
        [ -f "$FOUND_DIR/package.json" ] && echo "Yes" || echo "No"
        echo ""
        
        if [ -f "$FOUND_DIR/package.json" ]; then
            echo "Package.json content:"
            cat "$FOUND_DIR/package.json"
            echo ""
        fi
    fi

    # Check for running Node processes
    echo "=== NODE.JS PROCESSES ==="
    ps aux | grep -E "node|npm" | grep -v grep || echo "No Node.js processes found"
    echo ""

    # Check port 3000
    echo "=== PORT 3000 STATUS ==="
    if command -v netstat &> /dev/null; then
        netstat -tlnp | grep :3000 || echo "Port 3000 not in use"
    elif command -v ss &> /dev/null; then
        ss -tlnp | grep :3000 || echo "Port 3000 not in use"
    else
        echo "Neither netstat nor ss available"
    fi
    echo ""

    # Test local connection to port 3000
    echo "=== LOCAL PORT 3000 TEST ==="
    if command -v curl &> /dev/null; then
        curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost:3000 2>&1 || echo "Cannot connect to localhost:3000"
    else
        echo "curl not available"
    fi
    echo ""

    # Cloudflared Status
    echo "=== CLOUDFLARED STATUS ==="
    
    # Check if cloudflared is installed
    if command -v cloudflared &> /dev/null; then
        echo "Cloudflared version:"
        cloudflared --version
        echo ""
    else
        echo "Cloudflared not installed"
        echo ""
    fi

    # Check systemd service
    echo "Cloudflared service status:"
    if systemctl is-active --quiet cloudflared 2>/dev/null; then
        systemctl status cloudflared --no-pager -l
    else
        echo "Cloudflared service not active or systemd not available"
    fi
    echo ""

    # Check for running cloudflared processes
    echo "Running cloudflared processes:"
    ps aux | grep cloudflared | grep -v grep || echo "No cloudflared processes found"
    echo ""

    # Cloudflared Configuration
    echo "=== CLOUDFLARED CONFIGURATION ==="
    
    CONFIG_LOCATIONS=(
        "/etc/cloudflared/config.yml"
        "/root/.cloudflared/config.yml"
        "$HOME/.cloudflared/config.yml"
    )
    
    for config in "${CONFIG_LOCATIONS[@]}"; do
        if [ -f "$config" ]; then
            echo "Found config at: $config"
            echo "Content:"
            cat "$config"
            echo ""
        fi
    done
    
    # Check credentials
    CRED_LOCATIONS=(
        "/etc/cloudflared/credentials.json"
        "/root/.cloudflared/credentials.json"
        "$HOME/.cloudflared/credentials.json"
    )
    
    for cred in "${CRED_LOCATIONS[@]}"; do
        if [ -f "$cred" ]; then
            echo "Found credentials at: $cred"
            echo "File size: $(stat -f%z "$cred" 2>/dev/null || stat -c%s "$cred" 2>/dev/null) bytes"
            echo "Permissions: $(ls -l "$cred" | awk '{print $1}')"
            echo "First 100 chars (redacted):"
            head -c 100 "$cred" | sed 's/[a-zA-Z0-9+/=]\{20,\}/[REDACTED]/g'
            echo ""
            
            # Validate JSON
            echo "JSON validation:"
            if command -v jq &> /dev/null; then
                jq empty "$cred" 2>&1 && echo "Valid JSON" || echo "Invalid JSON"
            else
                python3 -c "import json; json.load(open('$cred'))" 2>&1 && echo "Valid JSON" || echo "Invalid JSON"
            fi
            echo ""
        fi
    done

    # Cloudflared Logs
    echo "=== CLOUDFLARED LOGS (Last 100 lines) ==="
    
    LOG_LOCATIONS=(
        "/var/log/cloudflared.log"
        "/var/log/cloudflared/cloudflared.log"
        "$HOME/.cloudflared/cloudflared.log"
    )
    
    FOUND_LOG=false
    for log in "${LOG_LOCATIONS[@]}"; do
        if [ -f "$log" ]; then
            echo "Found log at: $log"
            echo "Last 100 lines:"
            tail -100 "$log"
            echo ""
            FOUND_LOG=true
            break
        fi
    done
    
    if [ "$FOUND_LOG" = false ]; then
        echo "No log file found, checking journalctl..."
        if command -v journalctl &> /dev/null; then
            journalctl -u cloudflared -n 100 --no-pager 2>/dev/null || echo "Cannot access journalctl logs"
        else
            echo "journalctl not available"
        fi
    fi
    echo ""

    # Network Configuration
    echo "=== NETWORK CONFIGURATION ==="
    echo "Network interfaces:"
    ip addr show 2>/dev/null || ifconfig 2>/dev/null || echo "Cannot get network info"
    echo ""
    
    echo "Routing table:"
    ip route show 2>/dev/null || route -n 2>/dev/null || echo "Cannot get routing info"
    echo ""
    
    echo "DNS configuration:"
    cat /etc/resolv.conf 2>/dev/null || echo "Cannot read resolv.conf"
    echo ""

    # Firewall Status
    echo "=== FIREWALL STATUS ==="
    if command -v ufw &> /dev/null; then
        echo "UFW status:"
        sudo ufw status verbose 2>/dev/null || echo "Cannot check UFW status"
        echo ""
    fi
    
    if command -v iptables &> /dev/null; then
        echo "IPTables rules:"
        sudo iptables -L -n 2>/dev/null || echo "Cannot check iptables"
        echo ""
    fi

    # System Resources
    echo "=== SYSTEM RESOURCES ==="
    echo "Memory usage:"
    free -h
    echo ""
    
    echo "Disk usage:"
    df -h
    echo ""
    
    echo "CPU info:"
    top -bn1 | head -20
    echo ""

    # Recent System Errors
    echo "=== RECENT SYSTEM ERRORS ==="
    if [ -f /var/log/syslog ]; then
        echo "Recent syslog errors:"
        grep -i error /var/log/syslog | tail -20 || echo "No recent errors"
    elif [ -f /var/log/messages ]; then
        echo "Recent message errors:"
        grep -i error /var/log/messages | tail -20 || echo "No recent errors"
    else
        echo "System log not accessible"
    fi
    echo ""

    # Connectivity Tests
    echo "=== CONNECTIVITY TESTS ==="
    echo "Testing DNS resolution:"
    nslookup alpha.holovitals.net 2>&1 || echo "DNS resolution failed"
    echo ""
    
    echo "Testing Cloudflare connectivity:"
    ping -c 3 1.1.1.1 2>&1 || echo "Cannot reach Cloudflare DNS"
    echo ""
    
    echo "Testing HTTPS connectivity:"
    curl -I https://www.cloudflare.com 2>&1 | head -5 || echo "HTTPS test failed"
    echo ""

    # Environment Variables
    echo "=== ENVIRONMENT VARIABLES ==="
    echo "PATH: $PATH"
    echo "NODE_ENV: ${NODE_ENV:-not set}"
    echo "PORT: ${PORT:-not set}"
    echo ""

    # Cron Jobs
    echo "=== CRON JOBS ==="
    echo "User crontab:"
    crontab -l 2>/dev/null || echo "No user crontab"
    echo ""
    
    echo "System crontab:"
    sudo cat /etc/crontab 2>/dev/null || echo "Cannot read system crontab"
    echo ""

    echo "=================================================="
    echo "Diagnostics collection complete!"
    echo "=================================================="

} > "$OUTPUT_FILE" 2>&1

echo ""
echo "Diagnostics saved to: $OUTPUT_FILE"
echo ""
echo "Please share this file for analysis."
echo "You can view it with: cat $OUTPUT_FILE"
echo "Or copy it: cat $OUTPUT_FILE | pbcopy (Mac) or xclip (Linux)"
echo ""

# Create a sanitized version without sensitive data
SANITIZED_FILE="holovitals-diagnostics-sanitized-$(date +%Y%m%d-%H%M%S).txt"
cat "$OUTPUT_FILE" | sed 's/AccountTag":\s*"[^"]*"/AccountTag": "[REDACTED]"/g' | \
    sed 's/TunnelSecret":\s*"[^"]*"/TunnelSecret": "[REDACTED]"/g' | \
    sed 's/tunnel:\s*[a-f0-9-]\{36\}/tunnel: [REDACTED-TUNNEL-ID]/g' > "$SANITIZED_FILE"

echo "Sanitized version (safe to share publicly): $SANITIZED_FILE"
echo ""