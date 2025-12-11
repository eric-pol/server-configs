#!/bin/bash

# --- CONFIGURATION ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
FILES_DIR="$REPO_ROOT/files"
TARGET_SMB_CONF="/etc/samba/smb.conf"

echo "--- 🚀 Start Deployment ---"

# 1. Update the Repo
echo "📥 1. Executing Git Pull..."
cd "$REPO_ROOT"
git pull origin main

# 2. VALIDATION
echo "🔍 2. Starting validation..."
if [ -f "$FILES_DIR$TARGET_SMB_CONF" ]; then
    if ! testparm -s "$FILES_DIR$TARGET_SMB_CONF" > /dev/null 2>&1; then
        echo "❌ CRITICAL ERROR: The new smb.conf contains errors!"
        exit 1
    else
        echo "   ✅ Samba config is valid."
    fi
fi

# 3. CAPTURE STATE (Before Sync)
# We calculate the 'fingerprint' (MD5 hash) of the current live file
# If the file doesn't exist yet, we set the hash to "none"
if [ -f "$TARGET_SMB_CONF" ]; then
    PRE_HASH=$(md5sum "$TARGET_SMB_CONF" | awk '{print $1}')
else
    PRE_HASH="none"
fi

# 4. SYNCHRONIZE
echo "🔄 3. Synchronizing files..."
sudo rsync -av --no-owner --no-group "$FILES_DIR/" /

# 5. CHECK CHANGES & RESTART
echo "⚡ 4. Checking for changes..."

# Calculate the hash again (After Sync)
if [ -f "$TARGET_SMB_CONF" ]; then
    POST_HASH=$(md5sum "$TARGET_SMB_CONF" | awk '{print $1}')
else
    POST_HASH="none"
fi

# Compare the two fingerprints - if different restart Samba (smbd & nmbd (netbios names))
if [ "$PRE_HASH" != "$POST_HASH" ]; then
    echo "   ⚠️  Configuration changed! Restarting Samba..."
    sudo systemctl restart smbd
    sudo systemctl restart nmbd
    echo "   ✅ Services restarted."
else
    echo "   ☕ No changes in Samba configuration. Skipping restart."
fi

echo "--- 🎉 Done! ---"
