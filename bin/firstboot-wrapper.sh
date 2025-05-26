#!/bin/bash

# === CONFIGURATION ===
TARGET_SCRIPT="/home/ylabs/raspberry-farm-scripts/raspfarm_installer.sh"
LOG_FILE="/var/log/raspfarm_installer.log"
SERVICE_NAME="firstboot-raspfarm-installer.service"

# === LOGGING SETUP ===
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(date)] Starting first boot script..."

# === CHECK SCRIPT EXISTS ===
if [[ ! -x "$TARGET_SCRIPT" ]]; then
  echo "ERROR: Target script $TARGET_SCRIPT not found or not executable!"
  exit 1
fi

# === RUN THE TARGET SCRIPT ===
"$TARGET_SCRIPT"
RETVAL=$?

if [[ $RETVAL -eq 0 ]]; then
  echo "[$(date)] Script executed successfully. Disabling systemd service..."
  systemctl disable "$SERVICE_NAME"

  # Optional: Add a success marker for debugging or automation
  touch /var/lib/raspberry-firstboot-success

  echo "[$(date)] Rebooting system to finalize configuration..."
  reboot
else
  echo "[$(date)] ERROR: Script failed with exit code $RETVAL. Not disabling service."
  exit $RETVAL
fi
