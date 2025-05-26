# 🍓 Raspberry Pi OLED Stats Display Installer

This project automates the installation of all required components for an OLED-based system stats display on Raspberry Pi running Ubuntu 24.04 Server (ARM64). It uses a `firstboot`-triggered installer and Python systemd service to power up a Blinka/SSD1306-based display setup.

---

## 🧰 What It Does

- Prepares the Raspberry Pi with all necessary system tools.
- Installs Miniconda to `/opt/miniconda`.
- Creates and populates a `statsenv` Python environment.
- Sets up systemd services for:
  - First-time setup (`firstboot-display-installer.service`)
  - OLED stats script (`mystats.service`)
- Automates all steps with a single install + reboot.

---

## 🚀 Step-by-Step Setup

### 1. 🔧 Flash & Prepare the SD Card

- Flash **Ubuntu 24.04 Server (ARM64)** for Raspberry Pi.
- Boot the Pi, log in and set up SSH if needed.
- Update the system:

    ```bash
    sudo apt update && sudo apt upgrade -y
    ```

### 2. 📦 Clone and Run the Installer

```bash
git clone https://github.com/Jaezzehe/raspberry-farm-scripts.git
cd raspberry-farm-scripts
chmod +x install.sh
sudo ./install.sh
```

The `install.sh` script performs:

- System package installs (`wget`, `i2c-tools`, etc.)
- Folder creation under `/opt` and `/home/ylabs`
  - File copy and permissioning:
    - `stats.py` (OLED script)
    - `run_stats.sh` (conda wrapper)
    - `display_dependency_installer.sh` (main setup script)
    - `firstboot-wrapper.sh` (runs setup once at boot)
- Sets up `firstboot-display-installer.service` to trigger the setup on next reboot

---

## 🧩 File Placement Overview

| File                                      | Destination                                         | Permissions | Owner  |
|--------------------------------------------|-----------------------------------------------------|-------------|--------|
| `scripts/stats.py`                        | `/opt/raspberry-farm-scripts/stats.py`              | `+x`        | root   |
| `scripts/run_stats.sh`                    | `/opt/raspberry-farm-scripts/run_stats.sh`          | `+x`        | root   |
| `scripts/display_dependency_installer.sh`  | `/home/ylabs/raspberry-farm-scripts/...`            | `+x`        | ylabs  |
| `bin/firstboot-wrapper.sh`                 | `/usr/local/bin/firstboot-wrapper.sh`               | `+x`        | root   |
| `systemd/firstboot-display-installer.service` | `/etc/systemd/system/...`                        | —           | root   |

---

## 🔄 What Happens on Reboot?

- `firstboot-display-installer.service` launches on first boot
- It runs `firstboot-wrapper.sh`, which:
  - Executes `display_dependency_installer.sh`
  - Installs Miniconda + `statsenv` environment
  - Installs Python packages
  - Installs and enables `mystats.service`
  - Disables itself on success
  - Touches `/var/lib/raspberry-firstboot-success`
  - Reboots the Pi

---

## 🔁 Manual Testing / Re-run

To run setup again:

```bash
sudo /usr/local/bin/firstboot-wrapper.sh
```

To simulate first boot again:

```bash
sudo rm /var/lib/raspberry-firstboot-success
sudo systemctl enable firstboot-display-installer.service
sudo reboot
```

---

## ✅ Status Check

```bash
systemctl status mystats.service
systemctl status firstboot-display-installer.service
cat /var/log/display_dependency_installer.log
```

---

## 📜 License

MIT — see [LICENSE](LICENSE)
