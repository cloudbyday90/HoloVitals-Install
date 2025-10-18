#!/bin/bash

# HoloVitals Enhanced Error Analyzer
# Advanced error analysis and pattern detection for Cloudflare tunnel issues
# Run with: bash enhanced-error-analyzer.sh

set -e

OUTPUT_FILE="error-analysis-$(date +%Y%m%d-%H%M%S).txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================${NC}"
}

print_section() {
    echo -e "${CYAN}--- $1 ---${NC}"
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

print_info() {
    echo -e "${MAGENTA}ℹ $1${NC}"
}

print_header "HoloVitals Enhanced Error Analyzer"
echo ""
echo "Analyzing system for connection errors and patterns..."
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

# Start output file
{
    echo "HoloVitals Enhanced Error Analysis Report"
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "=================================================="
    echo ""

    # ============================================
    # SECTION 1: ERROR PATTERN DETECTION
    # ============================================
    echo "=== ERROR PATTERN DETECTION ==="
    echo ""

    # Find cloudflared logs
    LOG_FILES=(
        "/var/log/cloudflared.log"
        "/var/log/cloudflared/cloudflared.log"
        "$HOME/.cloudflared/cloudflared.log"
    )

    ACTIVE_LOG=""
    for log in "${LOG_FILES[@]}"; do
        if [ -f "$log" ]; then
            ACTIVE_LOG="$log"
            echo "Found active log: $log"
            break
        fi
    done

    if [ -z "$ACTIVE_LOG" ]; then
        echo "No log file found, checking journalctl..."
        if command -v journalctl &> /dev/null; then
            ACTIVE_LOG="journalctl"
            echo "Using journalctl for log analysis"
        else
            echo "WARNING: No logs available for analysis"
        fi
    fi
    echo ""

    if [ -n "$ACTIVE_LOG" ]; then
        echo "--- Common Error Patterns (Last 500 Lines) ---"
        echo ""

        # Get logs
        if [ "$ACTIVE_LOG" = "journalctl" ]; then
            LOGS=$(journalctl -u cloudflared -n 500 --no-pager 2>/dev/null || echo "")
        else
            LOGS=$(tail -500 "$ACTIVE_LOG" 2>/dev/null || echo "")
        fi

        # Pattern 1: Connection Errors
        echo "1. Connection Errors:"
        CONN_ERRORS=$(echo "$LOGS" | grep -i "connection\|connect" | grep -i "error\|fail" | wc -l)
        echo "   Total connection errors: $CONN_ERRORS"
        if [ $CONN_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "connection\|connect" | grep -i "error\|fail" | tail -5 | sed 's/^/   /'
        fi
        echo ""

        # Pattern 2: Accept Stream Listener Errors
        echo "2. Accept Stream Listener Errors:"
        STREAM_ERRORS=$(echo "$LOGS" | grep -i "accept stream listener" | wc -l)
        echo "   Total occurrences: $STREAM_ERRORS"
        if [ $STREAM_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "accept stream listener" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - This error indicates connection timeout or network issues"
            echo "   - Often caused by high latency or packet loss"
            echo "   - May require QUIC protocol or increased timeouts"
        fi
        echo ""

        # Pattern 3: Context Canceled Errors
        echo "3. Context Canceled Errors:"
        CONTEXT_ERRORS=$(echo "$LOGS" | grep -i "context canceled" | wc -l)
        echo "   Total occurrences: $CONTEXT_ERRORS"
        if [ $CONTEXT_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "context canceled" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - Request was canceled before completion"
            echo "   - Often caused by application not responding in time"
            echo "   - Check if local service is healthy and responsive"
        fi
        echo ""

        # Pattern 4: Authentication Errors
        echo "4. Authentication/Credentials Errors:"
        AUTH_ERRORS=$(echo "$LOGS" | grep -i "auth\|credential\|token\|unauthorized" | grep -i "error\|fail\|invalid" | wc -l)
        echo "   Total occurrences: $AUTH_ERRORS"
        if [ $AUTH_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "auth\|credential\|token\|unauthorized" | grep -i "error\|fail\|invalid" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - Credentials may be invalid or expired"
            echo "   - Check credentials.json file integrity"
            echo "   - May need to recreate credentials from tunnel token"
        fi
        echo ""

        # Pattern 5: Network/DNS Errors
        echo "5. Network/DNS Errors:"
        NET_ERRORS=$(echo "$LOGS" | grep -i "dns\|network\|resolve\|lookup" | grep -i "error\|fail" | wc -l)
        echo "   Total occurrences: $NET_ERRORS"
        if [ $NET_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "dns\|network\|resolve\|lookup" | grep -i "error\|fail" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - DNS resolution or network connectivity issues"
            echo "   - Check /etc/resolv.conf and network configuration"
            echo "   - Verify internet connectivity to Cloudflare"
        fi
        echo ""

        # Pattern 6: Protocol Errors
        echo "6. Protocol/QUIC Errors:"
        PROTO_ERRORS=$(echo "$LOGS" | grep -i "protocol\|quic\|http2" | grep -i "error\|fail" | wc -l)
        echo "   Total occurrences: $PROTO_ERRORS"
        if [ $PROTO_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "protocol\|quic\|http2" | grep -i "error\|fail" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - Protocol-specific issues"
            echo "   - May benefit from switching between QUIC and HTTP/2"
            echo "   - Check protocol configuration in config.yml"
        fi
        echo ""

        # Pattern 7: Timeout Errors
        echo "7. Timeout Errors:"
        TIMEOUT_ERRORS=$(echo "$LOGS" | grep -i "timeout\|timed out" | wc -l)
        echo "   Total occurrences: $TIMEOUT_ERRORS"
        if [ $TIMEOUT_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "timeout\|timed out" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - Operations taking too long to complete"
            echo "   - May need to increase timeout values"
            echo "   - Check application response time"
        fi
        echo ""

        # Pattern 8: Permission Errors
        echo "8. Permission/Access Errors:"
        PERM_ERRORS=$(echo "$LOGS" | grep -i "permission\|access denied\|forbidden" | wc -l)
        echo "   Total occurrences: $PERM_ERRORS"
        if [ $PERM_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "permission\|access denied\|forbidden" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - File or system permission issues"
            echo "   - Check credentials.json permissions (should be 600)"
            echo "   - Verify cloudflared running with correct user"
        fi
        echo ""

        # Pattern 9: Service/Origin Errors
        echo "9. Origin Service Errors:"
        ORIGIN_ERRORS=$(echo "$LOGS" | grep -i "origin\|upstream\|backend" | grep -i "error\|fail\|unavailable" | wc -l)
        echo "   Total occurrences: $ORIGIN_ERRORS"
        if [ $ORIGIN_ERRORS -gt 0 ]; then
            echo "   Sample errors:"
            echo "$LOGS" | grep -i "origin\|upstream\|backend" | grep -i "error\|fail\|unavailable" | tail -5 | sed 's/^/   /'
            echo ""
            echo "   Analysis:"
            echo "   - Local application (port 3000) may not be responding"
            echo "   - Check if application is running and healthy"
            echo "   - Verify port 3000 is accessible locally"
        fi
        echo ""

        # Pattern 10: Registration Errors
        echo "10. Tunnel Registration Errors:"
        REG_ERRORS=$(echo "$LOGS" | grep -i "register\|registration" | grep -i "error\|fail" | wc -l)
        echo "    Total occurrences: $REG_ERRORS"
        if [ $REG_ERRORS -gt 0 ]; then
            echo "    Sample errors:"
            echo "$LOGS" | grep -i "register\|registration" | grep -i "error\|fail" | tail -5 | sed 's/^/    /'
            echo ""
            echo "    Analysis:"
            echo "    - Tunnel failed to register with Cloudflare"
            echo "    - Check tunnel ID and credentials"
            echo "    - Verify Cloudflare account status"
        fi
        echo ""
    fi

    # ============================================
    # SECTION 2: ERROR FREQUENCY ANALYSIS
    # ============================================
    echo "=== ERROR FREQUENCY ANALYSIS ==="
    echo ""

    if [ -n "$ACTIVE_LOG" ] && [ -n "$LOGS" ]; then
        echo "--- Error Rate Over Time (Last 500 Lines) ---"
        echo ""

        # Count errors by hour (if timestamps available)
        echo "Errors by severity:"
        CRITICAL=$(echo "$LOGS" | grep -i "critical\|fatal" | wc -l)
        ERROR=$(echo "$LOGS" | grep -i "error" | wc -l)
        WARNING=$(echo "$LOGS" | grep -i "warn" | wc -l)
        INFO=$(echo "$LOGS" | grep -i "info" | wc -l)

        echo "  CRITICAL: $CRITICAL"
        echo "  ERROR:    $ERROR"
        echo "  WARNING:  $WARNING"
        echo "  INFO:     $INFO"
        echo ""

        # Calculate error rate
        TOTAL_LINES=$(echo "$LOGS" | wc -l)
        if [ $TOTAL_LINES -gt 0 ]; then
            ERROR_RATE=$((ERROR * 100 / TOTAL_LINES))
            echo "Error rate: ${ERROR_RATE}% of log lines contain errors"
            echo ""

            if [ $ERROR_RATE -gt 50 ]; then
                echo "⚠ HIGH ERROR RATE DETECTED!"
                echo "   More than 50% of logs are errors - immediate attention required"
            elif [ $ERROR_RATE -gt 20 ]; then
                echo "⚠ ELEVATED ERROR RATE"
                echo "   More than 20% of logs are errors - investigation recommended"
            elif [ $ERROR_RATE -gt 5 ]; then
                echo "ℹ MODERATE ERROR RATE"
                echo "   Some errors present but within acceptable range"
            else
                echo "✓ LOW ERROR RATE"
                echo "   Error rate is low and acceptable"
            fi
        fi
        echo ""

        # Most common error messages
        echo "--- Top 10 Most Common Error Messages ---"
        echo ""
        echo "$LOGS" | grep -i "error" | sed 's/.*error[: ]*//' | sort | uniq -c | sort -rn | head -10 | nl
        echo ""
    fi

    # ============================================
    # SECTION 3: SYSTEM HEALTH INDICATORS
    # ============================================
    echo "=== SYSTEM HEALTH INDICATORS ==="
    echo ""

    # Check if cloudflared is running
    echo "--- Service Status ---"
    if pgrep -x cloudflared > /dev/null; then
        echo "✓ Cloudflared process is running"
        echo "  PID: $(pgrep -x cloudflared)"
        echo "  Running time: $(ps -p $(pgrep -x cloudflared) -o etime= 2>/dev/null || echo 'Unknown')"
    else
        echo "✗ Cloudflared process is NOT running"
    fi
    echo ""

    # Check systemd service
    if command -v systemctl &> /dev/null; then
        echo "--- Systemd Service Status ---"
        if systemctl is-active --quiet cloudflared 2>/dev/null; then
            echo "✓ Systemd service is active"
            systemctl status cloudflared --no-pager -l | head -20
        else
            echo "✗ Systemd service is not active"
            systemctl status cloudflared --no-pager -l 2>&1 | head -20 || echo "Service not found"
        fi
        echo ""
    fi

    # Check application on port 3000
    echo "--- Application Health (Port 3000) ---"
    if netstat -tlnp 2>/dev/null | grep -q ":3000" || ss -tlnp 2>/dev/null | grep -q ":3000"; then
        echo "✓ Port 3000 is listening"
        
        # Try to connect
        if command -v curl &> /dev/null; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>&1 || echo "000")
            if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
                echo "✓ Application responding with HTTP $HTTP_CODE"
            else
                echo "⚠ Application returned HTTP $HTTP_CODE"
            fi
        fi
    else
        echo "✗ Port 3000 is NOT listening"
        echo "  Application may not be running"
    fi
    echo ""

    # Check network connectivity
    echo "--- Network Connectivity ---"
    
    # Test Cloudflare DNS
    if ping -c 1 1.1.1.1 &> /dev/null; then
        echo "✓ Can reach Cloudflare DNS (1.1.1.1)"
    else
        echo "✗ Cannot reach Cloudflare DNS (1.1.1.1)"
    fi

    # Test DNS resolution
    if nslookup cloudflare.com &> /dev/null; then
        echo "✓ DNS resolution working"
    else
        echo "✗ DNS resolution failing"
    fi

    # Test HTTPS connectivity
    if command -v curl &> /dev/null; then
        if curl -s -o /dev/null -w "%{http_code}" https://www.cloudflare.com | grep -q "200\|301\|302"; then
            echo "✓ HTTPS connectivity working"
        else
            echo "✗ HTTPS connectivity failing"
        fi
    fi
    echo ""

    # ============================================
    # SECTION 4: CONFIGURATION ANALYSIS
    # ============================================
    echo "=== CONFIGURATION ANALYSIS ==="
    echo ""

    # Check config.yml
    CONFIG_LOCATIONS=(
        "/etc/cloudflared/config.yml"
        "/root/.cloudflared/config.yml"
        "$HOME/.cloudflared/config.yml"
    )

    echo "--- Configuration File Analysis ---"
    CONFIG_FOUND=false
    for config in "${CONFIG_LOCATIONS[@]}"; do
        if [ -f "$config" ]; then
            CONFIG_FOUND=true
            echo "Found config: $config"
            echo ""
            
            # Check for common issues
            echo "Configuration checks:"
            
            # Check protocol
            if grep -q "protocol:" "$config"; then
                PROTOCOL=$(grep "protocol:" "$config" | awk '{print $2}')
                echo "  Protocol: $PROTOCOL"
                if [ "$PROTOCOL" = "quic" ]; then
                    echo "  ✓ Using QUIC (recommended for reliability)"
                elif [ "$PROTOCOL" = "http2" ]; then
                    echo "  ℹ Using HTTP/2 (consider QUIC for better reliability)"
                fi
            else
                echo "  ⚠ Protocol not specified (will use default)"
            fi
            
            # Check timeouts
            if grep -q "connectTimeout" "$config"; then
                TIMEOUT=$(grep "connectTimeout" "$config" | awk '{print $2}')
                echo "  Connect timeout: $TIMEOUT"
            else
                echo "  ⚠ Connect timeout not specified"
            fi
            
            if grep -q "keepAliveTimeout" "$config"; then
                KEEPALIVE=$(grep "keepAliveTimeout" "$config" | awk '{print $2}')
                echo "  Keep-alive timeout: $KEEPALIVE"
            else
                echo "  ⚠ Keep-alive timeout not specified"
            fi
            
            # Check ingress rules
            if grep -q "ingress:" "$config"; then
                echo "  ✓ Ingress rules defined"
                INGRESS_COUNT=$(grep -A 100 "ingress:" "$config" | grep "hostname:" | wc -l)
                echo "    Number of routes: $INGRESS_COUNT"
            else
                echo "  ✗ No ingress rules found"
            fi
            
            echo ""
            echo "Full configuration:"
            cat "$config"
            echo ""
            break
        fi
    done

    if [ "$CONFIG_FOUND" = false ]; then
        echo "✗ No configuration file found"
        echo "  Expected locations:"
        for config in "${CONFIG_LOCATIONS[@]}"; do
            echo "    - $config"
        done
    fi
    echo ""

    # Check credentials
    CRED_LOCATIONS=(
        "/etc/cloudflared/credentials.json"
        "/root/.cloudflared/credentials.json"
        "$HOME/.cloudflared/credentials.json"
    )

    echo "--- Credentials File Analysis ---"
    CRED_FOUND=false
    for cred in "${CRED_LOCATIONS[@]}"; do
        if [ -f "$cred" ]; then
            CRED_FOUND=true
            echo "Found credentials: $cred"
            
            # Check file permissions
            PERMS=$(stat -c %a "$cred" 2>/dev/null || stat -f %A "$cred" 2>/dev/null)
            echo "  Permissions: $PERMS"
            if [ "$PERMS" = "600" ]; then
                echo "  ✓ Correct permissions (600)"
            else
                echo "  ⚠ Incorrect permissions (should be 600)"
            fi
            
            # Check file size
            SIZE=$(stat -c %s "$cred" 2>/dev/null || stat -f %z "$cred" 2>/dev/null)
            echo "  File size: $SIZE bytes"
            if [ $SIZE -lt 50 ]; then
                echo "  ⚠ File seems too small, may be corrupted"
            fi
            
            # Validate JSON
            echo "  JSON validation:"
            if command -v jq &> /dev/null; then
                if jq empty "$cred" 2>&1; then
                    echo "  ✓ Valid JSON"
                    
                    # Check for required fields
                    if jq -e '.TunnelID' "$cred" &> /dev/null; then
                        echo "  ✓ TunnelID present"
                    else
                        echo "  ✗ TunnelID missing"
                    fi
                    
                    if jq -e '.TunnelSecret' "$cred" &> /dev/null; then
                        echo "  ✓ TunnelSecret present"
                    else
                        echo "  ✗ TunnelSecret missing"
                    fi
                else
                    echo "  ✗ Invalid JSON"
                fi
            else
                if python3 -c "import json; json.load(open('$cred'))" 2>&1; then
                    echo "  ✓ Valid JSON"
                else
                    echo "  ✗ Invalid JSON"
                fi
            fi
            echo ""
            break
        fi
    done

    if [ "$CRED_FOUND" = false ]; then
        echo "✗ No credentials file found"
        echo "  Expected locations:"
        for cred in "${CRED_LOCATIONS[@]}"; do
            echo "    - $cred"
        done
    fi
    echo ""

    # ============================================
    # SECTION 5: RECOMMENDED ACTIONS
    # ============================================
    echo "=== RECOMMENDED ACTIONS ==="
    echo ""

    RECOMMENDATIONS=()

    # Analyze and provide recommendations
    if [ -n "$LOGS" ]; then
        if [ $STREAM_ERRORS -gt 10 ]; then
            RECOMMENDATIONS+=("HIGH PRIORITY: Fix 'accept stream listener' errors - Consider switching to QUIC protocol and increasing timeouts")
        fi

        if [ $CONTEXT_ERRORS -gt 10 ]; then
            RECOMMENDATIONS+=("HIGH PRIORITY: Fix 'context canceled' errors - Check application health and response time")
        fi

        if [ $AUTH_ERRORS -gt 0 ]; then
            RECOMMENDATIONS+=("CRITICAL: Fix authentication errors - Recreate credentials from tunnel token")
        fi

        if [ $NET_ERRORS -gt 5 ]; then
            RECOMMENDATIONS+=("MEDIUM PRIORITY: Fix network/DNS errors - Check network configuration and connectivity")
        fi

        if [ $TIMEOUT_ERRORS -gt 10 ]; then
            RECOMMENDATIONS+=("MEDIUM PRIORITY: Fix timeout errors - Increase timeout values in configuration")
        fi

        if [ $ORIGIN_ERRORS -gt 5 ]; then
            RECOMMENDATIONS+=("HIGH PRIORITY: Fix origin service errors - Ensure application is running and healthy on port 3000")
        fi
    fi

    # Check if service is not running
    if ! pgrep -x cloudflared > /dev/null; then
        RECOMMENDATIONS+=("CRITICAL: Start cloudflared service - Service is not running")
    fi

    # Check if port 3000 is not listening
    if ! netstat -tlnp 2>/dev/null | grep -q ":3000" && ! ss -tlnp 2>/dev/null | grep -q ":3000"; then
        RECOMMENDATIONS+=("CRITICAL: Start application on port 3000 - Application is not running")
    fi

    # Check configuration issues
    if [ "$CONFIG_FOUND" = false ]; then
        RECOMMENDATIONS+=("CRITICAL: Create configuration file - No config.yml found")
    fi

    if [ "$CRED_FOUND" = false ]; then
        RECOMMENDATIONS+=("CRITICAL: Create credentials file - No credentials.json found")
    fi

    # Display recommendations
    if [ ${#RECOMMENDATIONS[@]} -eq 0 ]; then
        echo "✓ No critical issues detected"
        echo ""
        echo "System appears to be functioning normally."
        echo "Continue monitoring logs for any new issues."
    else
        echo "Found ${#RECOMMENDATIONS[@]} recommendations:"
        echo ""
        for i in "${!RECOMMENDATIONS[@]}"; do
            echo "$((i+1)). ${RECOMMENDATIONS[$i]}"
        done
    fi
    echo ""

    # ============================================
    # SECTION 6: QUICK FIX SUGGESTIONS
    # ============================================
    echo "=== QUICK FIX SUGGESTIONS ==="
    echo ""

    echo "Based on the analysis, here are suggested fixes:"
    echo ""

    if [ ${#RECOMMENDATIONS[@]} -gt 0 ]; then
        echo "1. Run the automated fix script:"
        echo "   sudo bash quick-fix-connection-errors.sh"
        echo ""
        
        echo "2. Or apply targeted fixes:"
        echo ""
        
        if [ $AUTH_ERRORS -gt 0 ] || [ "$CRED_FOUND" = false ]; then
            echo "   Fix credentials:"
            echo "   - Get new tunnel token from Cloudflare dashboard"
            echo "   - Run: sudo bash quick-fix-connection-errors.sh"
            echo ""
        fi
        
        if [ $STREAM_ERRORS -gt 10 ] || [ $TIMEOUT_ERRORS -gt 10 ]; then
            echo "   Optimize configuration:"
            echo "   - Switch to QUIC protocol"
            echo "   - Increase timeout values"
            echo "   - Add keepalive settings"
            echo ""
        fi
        
        if ! pgrep -x cloudflared > /dev/null; then
            echo "   Start service:"
            echo "   sudo systemctl start cloudflared"
            echo ""
        fi
        
        if ! netstat -tlnp 2>/dev/null | grep -q ":3000" && ! ss -tlnp 2>/dev/null | grep -q ":3000"; then
            echo "   Start application:"
            echo "   cd /path/to/HoloVitals && npm start"
            echo ""
        fi
    else
        echo "No immediate fixes required."
        echo "System is operating normally."
    fi
    echo ""

    # ============================================
    # SECTION 7: MONITORING COMMANDS
    # ============================================
    echo "=== MONITORING COMMANDS ==="
    echo ""
    
    echo "Use these commands to monitor your system:"
    echo ""
    echo "1. Watch live logs:"
    echo "   journalctl -u cloudflared -f"
    echo ""
    echo "2. Check service status:"
    echo "   systemctl status cloudflared"
    echo ""
    echo "3. Test local application:"
    echo "   curl http://localhost:3000"
    echo ""
    echo "4. Test domain:"
    echo "   curl -I https://alpha.holovitals.net"
    echo ""
    echo "5. Check for errors:"
    echo "   journalctl -u cloudflared -n 100 | grep -i error"
    echo ""

    echo "=================================================="
    echo "Analysis complete!"
    echo "=================================================="

} > "$OUTPUT_FILE" 2>&1

# Display summary to console
echo ""
print_success "Analysis complete!"
echo ""
echo "Report saved to: $OUTPUT_FILE"
echo ""

# Show key findings
print_header "Key Findings Summary"
echo ""

if [ -f "$OUTPUT_FILE" ]; then
    # Extract error counts
    if grep -q "Total connection errors:" "$OUTPUT_FILE"; then
        CONN_ERR=$(grep "Total connection errors:" "$OUTPUT_FILE" | awk '{print $4}')
        echo "Connection Errors: $CONN_ERR"
    fi
    
    if grep -q "Accept Stream Listener Errors:" "$OUTPUT_FILE"; then
        STREAM_ERR=$(grep "Total occurrences:" "$OUTPUT_FILE" | head -1 | awk '{print $3}')
        echo "Stream Listener Errors: $STREAM_ERR"
    fi
    
    if grep -q "Context Canceled Errors:" "$OUTPUT_FILE"; then
        CONTEXT_ERR=$(grep "Total occurrences:" "$OUTPUT_FILE" | sed -n '2p' | awk '{print $3}')
        echo "Context Canceled Errors: $CONTEXT_ERR"
    fi
    
    echo ""
    
    # Show recommendations count
    REC_COUNT=$(grep -c "PRIORITY:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
    if [ $REC_COUNT -gt 0 ]; then
        print_warning "Found $REC_COUNT recommendations"
        echo ""
        echo "Review the full report for details:"
        echo "cat $OUTPUT_FILE"
    else
        print_success "No critical issues detected"
    fi
fi

echo ""
print_info "For detailed analysis, view the full report:"
echo "cat $OUTPUT_FILE"
echo ""