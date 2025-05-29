#!/bin/bash
# install.sh - Prepares Raspberry Pi for first boot OLED installer (no actual execution)

set -e  # Exit on error

# === CONFIG ===
CONDA_DIR="/opt/miniconda"
ENV_NAME="statsenv"
TARGET_SCRIPT_DIR="/opt/raspberry-farm-scripts"
YLABS_HOME="/home/ylabs"
SRC_DIR="$(pwd)"
LOG_FILE="/var/log/raspfarm_installer.log"

# === 1. Basic system packages ===
echo "📦 Installing system dependencies..."
sudo apt update && sudo apt install -y wget git i2c-tools libgpiod-dev libi2c0 read-edid 

# === 2. Miniconda Installer Script (only download if needed) ===
if [ ! -f "$SRC_DIR/miniconda.sh" ]; then
  echo "📥 Downloading Miniconda..."
  wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O "$SRC_DIR/miniconda.sh"
fi

# === 3. Copy Scripts ===
echo "📁 Setting up script directory at $TARGET_SCRIPT_DIR..."
sudo mkdir -p "$TARGET_SCRIPT_DIR"
sudo cp "$SRC_DIR/scripts/stats.py" "$TARGET_SCRIPT_DIR/"
sudo cp "$SRC_DIR/scripts/run_stats.sh" "$TARGET_SCRIPT_DIR/"
sudo chmod +x "$TARGET_SCRIPT_DIR/"*.sh "$TARGET_SCRIPT_DIR/stats.py"
sudo chown root:root "$TARGET_SCRIPT_DIR/"*

# === 4. raspfarm installer Script ===
echo "🔧 Copying raspfarm_installer.sh to $YLABS_HOME..."
sudo mkdir -p "$YLABS_HOME/raspberry-farm-scripts"
sudo cp "$SRC_DIR/scripts/raspfarm_installer.sh" "$YLABS_HOME/raspberry-farm-scripts/"
sudo chmod +x "$YLABS_HOME/raspberry-farm-scripts/raspfarm_installer.sh"
sudo chown -R ylabs:ylabs "$YLABS_HOME/raspberry-farm-scripts"

# === 5. Wrapper Script ===
echo "🔁 Installing firstboot-wrapper.sh to /usr/local/bin..."
sudo cp "$SRC_DIR/bin/firstboot-wrapper.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/firstboot-wrapper.sh

# === 6. Systemd Unit ===
echo "⚙️ Installing firstboot systemd unit..."
sudo cp "$SRC_DIR/systemd/firstboot-raspfarm-installer.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable firstboot-raspfarm-installer.service

# === 7. Touch empty log for tracking ===
sudo touch "$LOG_FILE"
sudo chown ylabs:ylabs "$LOG_FILE"


# ==========================
# Final reboot after setup
# ==========================
echo ""
echo "=============================================="
echo " Setup completed successfully!"
echo " System will reboot in 5 seconds..."
echo "=============================================="
sleep 5
sudo reboot
