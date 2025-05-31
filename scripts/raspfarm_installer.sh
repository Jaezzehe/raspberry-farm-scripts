#!/bin/bash
###############################################################################
# Raspberry Pi Ubuntu Setup Script
#
# Automates setup for:
#   - Miniconda install + 'statsenv' conda environment (Python 3.9)
#   - OLED stats display Python dependencies (I2C, GPIO)
#   - I2C kernel configuration (modules, boot config)
#   - MicroK8s Kubernetes install
#   - stats.py systemd service (runs at boot)
#   - Halo-style progress spinners for user feedback
#
# USAGE:
#   sudo bash setup.sh
#
# REQUIREMENTS:
#   - Raspberry Pi running Ubuntu
#   - Internet access (downloads packages & scripts)
#
# RECOMMENDED USAGE:
#   1. Review this script for customization.
#   2. Run: sudo bash setup.sh
#
# Author: Timon Turro
# Last updated: 2025-05-26
###############################################################################


set -e 

## ==========================
## Set core environment vars
## ==========================

export CONDA_ROOT=/opt/miniconda
export ENV_PATH=$CONDA_ROOT/envs/statsenv
export PYTHON=$ENV_PATH/bin/python
export PIP=$ENV_PATH/bin/pip

## ==========================
## Ensure script runs as root
## ==========================

if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Use sudo:"
  echo "   sudo $0"
  exit 1
fi

## ==========================
## Setup progress spinner
## ==========================

spin='-\|/'
i=0
spinner_pid=0

start_spinner() {
  echo -n "$1 "
  (
    while true; do
      i=$(( (i+1) %4 ))
      printf "\b${spin:$i:1}"
      sleep 0.1
    done
  ) &
  spinner_pid=$!
  disown
}

stop_spinner() {
  if [ "$spinner_pid" != "0" ]; then
    kill "$spinner_pid" &>/dev/null || true
    spinner_pid=0
    echo -e "\b Done."
  fi
}

## ==========================
## Update and install basics
## ==========================

start_spinner "Updating package lists..."
sudo apt-get update -y
stop_spinner

start_spinner "Installing system packages..."
sudo apt-get install -y wget git i2c-tools libgpiod-dev libi2c0 read-edid
stop_spinner

## ==========================
## Download and setup Miniconda
## ==========================

start_spinner "Downloading Miniconda..."
wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O miniconda.sh
stop_spinner

if [ ! -x /opt/miniconda/bin/conda ]; then
  start_spinner "Installing Miniconda to /opt..."
  sudo bash miniconda.sh -b -p /opt/miniconda
  stop_spinner
else
  echo "Miniconda already installed at /opt/miniconda — skipping installation."
fi


eval "$(/opt/miniconda/bin/conda shell.bash hook)"

if [ -d "/opt/miniconda/envs/statsenv" ]; then
  echo "Conda environment 'statsenv' already exists — skipping creation."
else
  conda create --prefix /opt/miniconda/envs/statsenv python=3.9 -y
fi


start_spinner "Activating 'statsenv' environment..."
source /opt/miniconda/etc/profile.d/conda.sh
conda activate /opt/miniconda/envs/statsenv
PYTHON=/opt/miniconda/envs/statsenv/bin/python
PIP=/opt/miniconda/envs/statsenv/bin/pip
stop_spinner

## ==========================
## Install Python requirements
## ==========================

start_spinner "Installing compiler toolchain for Python packages..."
sudo apt-get install -y build-essential liblgpio1 liblgpio-dev
stop_spinner

# Path to statsenv's Python & pip
PYTHON=/opt/miniconda/envs/statsenv/bin/python
PIP=/opt/miniconda/envs/statsenv/bin/pip

# Upgrade pip
start_spinner "Upgrading pip inside statsenv..."
$PIP install --upgrade --break-system-packages pip
stop_spinner

# Function to check and install a Python module
check_and_install_module() {
  local module=$1
  local package=$2

  echo -n "Checking for Python module: $module... "
  if ! $PYTHON -c "import $module" 2>/dev/null; then
    echo "MISSING. Installing package: $package"
    $PIP install --break-system-packages "$package"
    if [ $? -ne 0 ]; then
      echo "❌ ERROR: Failed to install $package"
      exit 1
    fi
  else
    echo "OK"
  fi
}

# Install required Python modules (OLED + GPIO support)
check_and_install_module "lgpio" "lgpio"
check_and_install_module "PIL" "pillow"
check_and_install_module "board" "adafruit-blinka"
check_and_install_module "adafruit_ssd1306" "adafruit-circuitpython-ssd1306"

# Install general development tools
start_spinner "Installing general Python tools in statsenv..."
$PIP install --upgrade --break-system-packages \
  setuptools \
  wheel \
  build \
  click \
  gpiod \
  adafruit-python-shell
stop_spinner


## ==========================
## Clone and setup Adafruit tools
## ==========================

start_spinner "Setting /opt ownership to ylabs..."
sudo chown -R ylabs:ylabs /opt
stop_spinner

cd /opt
start_spinner "Cloning Adafruit Pi Installer Scripts..."
if [ ! -d "Raspberry-Pi-Installer-Scripts" ]; then
  git clone https://github.com/adafruit/Raspberry-Pi-Installer-Scripts.git
fi
stop_spinner

# Install build tools for libgpiod (for autoreconf)
start_spinner "Installing build tools for libgpiod..."
sudo apt-get install -y autoconf automake libtool m4 autoconf-archive
stop_spinner



cd Raspberry-Pi-Installer-Scripts
start_spinner "Running libgpiod.py with conda Python..."
if ! /opt/miniconda/envs/statsenv/bin/python libgpiod.py; then
  echo "❌ libgpiod.py failed. Check for missing build dependencies."
  exit 1
fi
stop_spinner


## ==========================
## Enable and configure I2C
## ==========================

start_spinner "Loading I2C kernel modules..."
sudo modprobe i2c-dev
sudo modprobe i2c-bcm2708
stop_spinner

start_spinner "Enabling I2C on boot..."
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
echo "i2c-bcm2708" | sudo tee /etc/modules-load.d/i2c-bcm2708.conf >/dev/null
stop_spinner

start_spinner "Configuring /boot/firmware/config.txt..."
if ! grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt; then
  echo "dtparam=i2c_arm=on" | sudo tee -a /boot/firmware/config.txt >/dev/null
fi
stop_spinner

## ==========================
## Install and configure MicroK8s
## ==========================

start_spinner "Installing MicroK8s via snap..."
sudo snap install microk8s --classic
stop_spinner

start_spinner "Adding user '$USER' to microk8s group..."
sudo usermod -aG microk8s "$USER"
stop_spinner

start_spinner "Waiting for MicroK8s to be ready..."
sudo microk8s status --wait-ready
stop_spinner

## ==========================
## Install and enable stats service
## ==========================

# Copy script
start_spinner "Preparing stats.py script..."
if [ ! -f /opt/raspberry-farm-scripts/stats.py ]; then
  sudo mkdir -p /opt/raspberry-farm-scripts
  sudo cp /home/ylabs/raspberry-farm-scripts/stats.py /opt/raspberry-farm-scripts/

  # Create wrapper script to activate conda env before running stats.py
  cat <<'EOF' | sudo tee /opt/raspberry-farm-scripts/run_stats.sh > /dev/null
#!/bin/bash
source /opt/miniconda/etc/profile.d/conda.sh
conda activate /opt/miniconda/envs/statsenv
exec python /opt/raspberry-farm-scripts/stats.py
EOF

  sudo chmod +x /opt/raspberry-farm-scripts/run_stats.sh
  sudo chown root:root /opt/raspberry-farm-scripts/stats.py
  sudo chmod +x /opt/raspberry-farm-scripts/stats.py
fi
stop_spinner

# Create unit

echo "Creating mystats.service..."
cat <<EOF | sudo tee /etc/systemd/system/mystats.service
[Unit]
Description=My Python Script Service
After=network.target

[Service]
Type=simple
ExecStart=/opt/raspberry-farm-scripts/run_stats.sh
User=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Enable service
start_spinner "Enabling mystats systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable mystats.service
stop_spinner


## ==========================
## Set up Auto-Cluster MicroK8s Bootstrap
## ==========================

echo "Setting up auto-cluster for MicroK8s..."

# Make sure autocluster scripts are executable
chmod +x /home/ylabs/raspberry-farm-scripts/autocluster/cluster-bootstrap.sh
chmod +x /home/ylabs/raspberry-farm-scripts/autocluster/serve-join.py

# Register systemd service for cluster bootstrap
cat <<EOF | sudo tee /etc/systemd/system/cluster-bootstrap.service > /dev/null
[Unit]
Description=MicroK8s Auto-Cluster Bootstrap
After=network.target

[Service]
Type=simple
ExecStart=/home/ylabs/raspberry-farm-scripts/autocluster/cluster-bootstrap.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable the service for next boot
sudo systemctl daemon-reload
sudo systemctl enable cluster-bootstrap.service

echo "Auto-cluster service installed! It will run on every boot and auto-join or auto-promote as needed."


## ==========================
## Final reboot after setup
## ==========================
echo ""
echo "=============================================="
echo " Setup completed successfully!"
echo " System will reboot in 5 seconds..."
echo "=============================================="
sleep 5
sudo reboot
