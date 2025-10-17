# Cloudflare Tunnel Credentials Fix

## Problem Identified

Your Cloudflare tunnel is failing with this error:
```
ERROR: The credentials file at /etc/cloudflared/credentials.json contained invalid JSON.
parsing credentials file: invalid character '+' looking for beginning of object key string
```

## Root Cause

The JWT token from Cloudflare was written directly to the credentials file instead of being properly parsed. The credentials file needs to contain a JSON object with three specific fields extracted from the JWT token:
- `AccountTag`
- `TunnelSecret`
- `TunnelID`

## The Fix

I've created a script that will:
1. ✅ Read your Cloudflare token from the installer configuration
2. ✅ Properly decode the JWT token (it's base64-encoded)
3. ✅ Extract the required fields from the token payload
4. ✅ Create a properly formatted `credentials.json` file
5. ✅ Validate the JSON format
6. ✅ Restart the Cloudflare tunnel service
7. ✅ Verify the tunnel is running

## How to Apply the Fix

### Option 1: Download and Run the Fix Script

```bash
# Download the fix script
wget https://raw.githubusercontent.com/cloudbyday90/HoloVitals-Install/main/fix-cloudflare-credentials.sh

# Make it executable
chmod +x fix-cloudflare-credentials.sh

# Run the fix
./fix-cloudflare-credentials.sh
```

### Option 2: Manual Steps (if script fails)

If the automated script doesn't work, here's how to fix it manually:

1. **Get your Cloudflare token:**
   ```bash
   source ~/HoloVitals/scripts/installer_config.txt
   echo $cloudflare_token
   ```

2. **Install jq (if not already installed):**
   ```bash
   sudo apt-get update
   sudo apt-get install -y jq
   ```

3. **Parse the JWT token:**
   ```bash
   # Split the token into parts
   IFS='.' read -ra PARTS <<< "$cloudflare_token"
   
   # Decode the payload (second part)
   PAYLOAD=$(echo "${PARTS[1]}" | base64 -d 2>/dev/null)
   
   # Extract fields
   ACCOUNT_TAG=$(echo "$PAYLOAD" | jq -r '.a')
   TUNNEL_SECRET=$(echo "$PAYLOAD" | jq -r '.s')
   TUNNEL_ID=$(echo "$PAYLOAD" | jq -r '.t')
   ```

4. **Create the credentials file:**
   ```bash
   sudo tee /etc/cloudflared/credentials.json > /dev/null <<EOF
   {
     "AccountTag": "$ACCOUNT_TAG",
     "TunnelSecret": "$TUNNEL_SECRET",
     "TunnelID": "$TUNNEL_ID"
   }
   EOF
   ```

5. **Set permissions:**
   ```bash
   sudo chmod 600 /etc/cloudflared/credentials.json
   ```

6. **Restart the service:**
   ```bash
   sudo systemctl restart cloudflared.service
   sudo systemctl status cloudflared.service
   ```

## Verification

After running the fix, verify the tunnel is working:

```bash
# Check service status
sudo systemctl status cloudflared.service

# Check recent logs
sudo journalctl -u cloudflared.service -n 50 --no-pager

# Verify credentials file format
sudo jq '.' /etc/cloudflared/credentials.json
```

The credentials file should look like this:
```json
{
  "AccountTag": "abc123...",
  "TunnelSecret": "xyz789...",
  "TunnelID": "uuid-here"
}
```

## Expected Output

When successful, you should see:
- ✅ Service status: `active (running)`
- ✅ No JSON parsing errors in logs
- ✅ Tunnel connected to Cloudflare edge
- ✅ Your domain accessible at `https://your-domain.com`

## Troubleshooting

### If the tunnel still fails after the fix:

1. **Check if the application is running:**
   ```bash
   curl http://localhost:3000
   ```
   If this fails, the Next.js application isn't running yet. The tunnel needs something to proxy to.

2. **Check the tunnel configuration:**
   ```bash
   sudo cat /etc/cloudflared/config.yml
   ```
   Should show `url: http://localhost:3000`

3. **Verify DNS records:**
   - Log into Cloudflare dashboard
   - Check that your domain has a CNAME record pointing to the tunnel

4. **Check application logs:**
   ```bash
   # If using PM2
   pm2 logs
   
   # If using systemd
   sudo journalctl -u holovitals.service -n 50
   ```

## Next Steps

After fixing the credentials:
1. Continue with the installer (if not completed)
2. Ensure the Next.js application is running on port 3000
3. Access your application at your configured domain

## Need Help?

If you encounter issues:
1. Run the diagnostic script: `./debug-installer.sh`
2. Check the logs: `sudo journalctl -u cloudflared.service -n 100`
3. Verify the credentials file: `sudo jq '.' /etc/cloudflared/credentials.json`

---

**Note:** This fix addresses the immediate credentials format issue. If the tunnel still fails after this fix, it's likely because the application isn't running on port 3000 yet, which is expected if you haven't completed the full installation.