#!/bin/bash

# --- CONFIGURATION ---
# Automatically determine location, regardless of where the script is called from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
FILES_DIR="$REPO_ROOT/files"

echo "--- 🚀 Start Deployment ---"

# 1. Update the Repo (Self-update)
echo "📥 1. Executing Git Pull..."
cd "$REPO_ROOT"
git pull origin main

# 2. VALIDATION (Safety First!)
echo "🔍 2. Starting validation..."

# Check Samba Config if it exists in the update
if [ -f "$FILES_DIR/etc/samba/smb.conf" ]; then
    # We test the config in the repo, NOT the live server one
    if ! testparm -s "$FILES_DIR/etc/samba/smb.conf" > /dev/null 2>&1; then
        echo "❌ CRITICAL ERROR: The new smb.conf contains errors!"
        echo "🛑 Deployment aborted. No changes made to the server."
        exit 1
    else
        echo "   ✅ Samba config is valid."
    fi
fi

# 3. RSYNC (Applying the Overlay)
echo "🔄 3. Synchronizing files..."
# This copies everything from 'files/' over the server root '/'
# -a: archive (preserves permissions)
# -v: verbose
# --no-owner --no-group: Let the server decide ownership (usually root)
sudo rsync -av --no-owner --no-group "$FILES_DIR/" /

# 4. RESTART SERVICES
echo "♻️  4. Restarting services..."

# Restart Samba only if the config exists on the system (both smbd and nmbd (netbios nameservice))
if [ -f "/etc/samba/smb.conf" ]; then
    sudo systemctl restart smbd
    sudo systemctl restart nmbd
    echo "   -> Samba services restarted"
fi

echo "--- 🎉 Done! Server updated successfully. ---"
