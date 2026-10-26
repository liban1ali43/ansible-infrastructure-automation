#!/bin/bash
set -euo pipefail

# --- Configuration ---
REPO_ROOT="/var/www/html/repo"
MOUNT_POINT="/mnt/dvd"
GPG_NAME="remote-repo@server.lab.example.com"
GPG_KEY_NAME="remote-repo"
GPG_KEY_PATH="/var/www/html/repo/RPM-GPG-KEY-remote-repo"

# --- 1. Create mount point and install required packages ---
mkdir -p "$MOUNT_POINT"
dnf install -y gnupg2 createrepo_c rpm-sign httpd

# --- 2. Configure RPM signing macros ---
cat > ~/.rpmmacros <<EOF
%_signature gpg
%_gpg_name $GPG_NAME
%_gpg_path /root/.gnupg
EOF

# --- 3. Mount the DVD ---
mount /dev/sr0 "$MOUNT_POINT"

# --- 4. Create repo directory structure ---
mkdir -p "$REPO_ROOT"/{BaseOS,AppStream}/Packages

# --- 5. Copy packages from DVD ---
rsync -av "$MOUNT_POINT/BaseOS/Packages/"    "$REPO_ROOT/BaseOS/Packages/"
rsync -av "$MOUNT_POINT/AppStream/Packages/" "$REPO_ROOT/AppStream/Packages/"

# --- 6. Re-sign all RPMs ---
rpm --resign "$REPO_ROOT"/BaseOS/Packages/*.rpm
rpm --resign "$REPO_ROOT"/AppStream/Packages/*.rpm

# --- 7. Import and export GPG key ---
gpg --import "$GPG_KEY_PATH" 2>/dev/null || true
gpg --armor --export "$GPG_KEY_NAME" > "$GPG_KEY_PATH"

# --- 8. Create repository metadata ---
createrepo_c "$REPO_ROOT/BaseOS/"
createrepo_c "$REPO_ROOT/AppStream/"

# --- 9. Detach-sign the repo metadata ---
gpg --detach-sign --armor "$REPO_ROOT/BaseOS/repodata/repomd.xml"
gpg --detach-sign --armor "$REPO_ROOT/AppStream/repodata/repomd.xml"

# --- 10. Cleanup: unmount DVD ---
umount "$MOUNT_POINT"

echo "Repository setup complete."
