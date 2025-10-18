#!/bin/bash

# HoloVitals Remote Diagnostics Collector v2
# Enhanced with integrated error analysis
# Run this script on your server to collect diagnostic information
# Then share the output file with support for analysis

set -e

OUTPUT_FILE="holovitals-diagnostics-$(date +%Y%m%d-%H%M%S).txt"

echo "=================================================="
echo "HoloVitals Remote Diagnostics Collector v2"
echo "=================================================="
echo ""
echo "Collecting diagnostic information..."
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

# Start output file
{
    echo "HoloVitals Diagnostics Report v2"
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
    LOG_FILE=""
    for log in "${LOG_LOCATIONS[@]}"; do
        if [ -f "$log" ]; then
            echo "Found log at: $log"
            echo "Last 100 lines:"
            tail -100 "$log"
            echo ""
            FOUND_LOG=true
            LOG_FILE="$log"
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

    # ============================================
    # INTEGRATED ERROR ANALYSIS
    # ============================================
    echo "=== INTEGRATED ERROR ANALYSIS ==="
    echo ""
    
    # Get logs for analysis
    if [ "$FOUND_LOG" = true ] && [ -n "$LOG_FILE" ]; then
        ANALYSIS_LOGS=$(tail -500 "$LOG_FILE" 2>/dev/null || echo "")
    elif command -v journalctl &> /dev/null; then
        ANALYSIS_LOGS=$(journalctl -u cloudflared -n 500 --no-pager 2>/dev/null || echo "")
    else
        ANALYSIS_LOGS=""
    fi
    
    if [ -n "$ANALYSIS_LOGS" ]; then
        echo "Analyzing last 500 log lines for error patterns..."
        echo ""
        
        # Count different error types
        CONN_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "connection\|connect" | grep -i "error\|fail" | wc -l)
        STREAM_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "accept stream listener" | wc -l)
        CONTEXT_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "context canceled" | wc -l)
        AUTH_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "auth\|credential\|token" | grep -i "error\|fail\|invalid" | wc -l)
        TIMEOUT_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "timeout\|timed out" | wc -l)
        ORIGIN_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "origin\|upstream" | grep -i "error\|fail\|unavailable" | wc -l)
        NET_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "dns\|network\|resolve" | grep -i "error\|fail" | wc -l)
        PROTO_ERRORS=$(echo "$ANALYSIS_LOGS" | grep -i "protocol\|quic\|http2" | grep -i "error\|fail" | wc -l)
        
        echo "--- Error Pattern Summary ---"
        echo ""
        echo "Error Type Counts (Last 500 log lines):"
        echo "  Connection errors:        $CONN_ERRORS"
        echo "  Stream listener errors:   $STREAM_ERRORS"
        echo "  Context canceled errors:  $CONTEXT_ERRORS"
        echo "  Authentication errors:    $AUTH_ERRORS"
        echo "  Timeout errors:           $TIMEOUT_ERRORS"
        echo "  Origin service errors:    $ORIGIN_ERRORS"
        echo "  Network/DNS errors:       $NET_ERRORS"
        echo "  Protocol errors:          $PROTO_ERRORS"
        echo ""
        
        # Calculate total and severity
        TOTAL_ERRORS=$((CONN_ERRORS + STREAM_ERRORS + CONTEXT_ERRORS + AUTH_ERRORS + TIMEOUT_ERRORS + ORIGIN_ERRORS + NET_ERRORS + PROTO_ERRORS))
        echo "Total errors detected: $TOTAL_ERRORS"
        echo ""
        
        # Severity assessment
        if [ $TOTAL_ERRORS -gt 100 ]; then
            echo "⚠ CRITICAL: Very high error count detected!"
            echo "   Immediate action required"
            echo "   Error rate: CRITICAL"
        elif [ $TOTAL_ERRORS -gt 50 ]; then
            echo "⚠ WARNING: High error count detected"
            echo "   Investigation recommended"
            echo "   Error rate: HIGH"
        elif [ $TOTAL_ERRORS -gt 10 ]; then
            echo "ℹ INFO: Moderate error count"
            echo "   Monitor and address if increasing"
            echo "   Error rate: MODERATE"
        else
            echo "✓ Low error count - system appears stable"
            echo "   Error rate: LOW"
        fi
        echo ""
        
        # Show sample errors for top issues
        if [ $STREAM_ERRORS -gt 0 ]; then
            echo "--- Sample Stream Listener Errors ---"
            echo "$ANALYSIS_LOGS" | grep -i "accept stream listener" | tail -3
            echo ""
        fi
        
        if [ $CONTEXT_ERRORS -gt 0 ]; then
            echo "--- Sample Context Canceled Errors ---"
            echo "$ANALYSIS_LOGS" | grep -i "context canceled" | tail -3
            echo ""
        fi
        
        if [ $AUTH_ERRORS -gt 0 ]; then
            echo "--- Sample Authentication Errors ---"
            echo "$ANALYSIS_LOGS" | grep -i "auth\|credential\|token" | grep -i "error\|fail\|invalid" | tail -3
            echo ""
        fi
        
        # Provide specific recommendations
        echo "--- Recommended Actions ---"
        echo ""
        
        PRIORITY_COUNT=0
        
        if [ $AUTH_ERRORS -gt 0 ]; then
            PRIORITY_COUNT=$((PRIORITY_COUNT + 1))
            echo "$PRIORITY_COUNT. CRITICAL: Fix authentication errors"
            echo "   - Recreate credentials from tunnel token"
            echo "   - Verify credentials.json is valid JSON"
            echo "   - Check file permissions (should be 600)"
            echo ""
        fi
        
        if [ $STREAM_ERRORS -gt 10 ]; then
            PRIORITY_COUNT=$((PRIORITY_COUNT + 1))
            echo "$PRIORITY_COUNT. HIGH PRIORITY: Address stream listener errors"
            echo "   - Switch to QUIC protocol"
            echo "   - Increase connection timeouts"
            echo "   - Check network stability"
            echo ""
        fi
        
        if [ $CONTEXT_ERRORS -gt 10 ]; then
            PRIORITY_COUNT=$((PRIORITY_COUNT + 1))
            echo "$PRIORITY_COUNT. HIGH PRIORITY: Address context canceled errors"
            echo "   - Verify application is responding quickly"
            echo "   - Check application health on port 3000"
            echo "   - Increase keepalive timeouts"
            echo ""
        fi
        
        if [ $ORIGIN_ERRORS -gt 5 ]; then
            PRIORITY_COUNT=$((PRIORITY_COUNT + 1))
            echo "$PRIORITY_COUNT. HIGH PRIORITY: Fix origin service errors"
            echo "   - Ensure application is running on port 3000"
            echo "   - Check application logs for errors"
            echo "   - Verify application is healthy"
            echo ""
        fi
        
        if [ $TIMEOUT_ERRORS -gt 10 ]; then
            PRIORITY_COUNT=$((PRIORITY_COUNT + 1))
            echo "$PRIORITY_COUNT. MEDIUM PRIORITY: Address timeout errors"
            echo "   - Increase timeout values in config"
            echo "   - Check application response time"
            echo "   - Verify network latency"
            echo ""
        fi
        
        if [ $NET_ERRORS -gt 5 ]; then
            PRIORITY_COUNT=$((PRIORITY_COUNT + 1))
            echo "$PRIORITY_COUNT. MEDIUM PRIORITY: Fix network/DNS errors"
            echo "   - Check network configuration"
            echo "   - Verify DNS resolution"
            echo "   - Test connectivity to Cloudflare"
            echo ""
        fi
        
        if [ $PRIORITY_COUNT -eq 0 ]; then
            echo "✓ No critical issues detected"
            echo "   System appears to be functioning normally"
            echo "   Continue monitoring logs for any new issues"
        else
            echo ""
            echo "RECOMMENDED: Run the automated fix script"
            echo "  sudo bash quick-fix-connection-errors.sh"
        fi
        echo ""
        
        # Top 10 most common errors
        echo "--- Top 10 Most Common Error Messages ---"
        echo ""
        echo "$ANALYSIS_LOGS" | grep -i "error" | sed 's/.*error[: ]*//' | sort | uniq -c | sort -rn | head -10 | nl
        echo ""
    else
        echo "No logs available for error analysis"
        echo ""
    fi

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

# Display quick summary
echo "=================================================="
echo "Quick Summary"
echo "=================================================="
echo ""

if grep -q "Total errors detected:" "$OUTPUT_FILE"; then
    TOTAL=$(grep "Total errors detected:" "$OUTPUT_FILE" | awk '{print $4}')
    echo "Total errors found: $TOTAL"
    
    if grep -q "Error rate:" "$OUTPUT_FILE"; then
        RATE=$(grep "Error rate:" "$OUTPUT_FILE" | tail -1 | awk '{print $3}')
        echo "Error severity: $RATE"
    fi
    echo ""
fi

if grep -q "CRITICAL:" "$OUTPUT_FILE"; then
    echo "⚠ Critical issues detected - review full report"
elif grep -q "HIGH PRIORITY:" "$OUTPUT_FILE"; then
    echo "⚠ High priority issues detected - review full report"
elif grep -q "MEDIUM PRIORITY:" "$OUTPUT_FILE"; then
    echo "ℹ Medium priority issues detected - review full report"
else
    echo "✓ No critical issues detected"
fi

echo ""
echo "For detailed analysis, view the full report:"
echo "cat $OUTPUT_FILE"
echo ""