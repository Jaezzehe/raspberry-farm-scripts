#!/bin/bash

# Path to the Python join server (adjust as needed)
JOIN_SERVER_SCRIPT="$(dirname "$0")/serve-join.py"

# Your interface (eth0 or wlan0, adjust as needed)
IFACE="eth0"

# Normalize and get own MAC (lowercase, no colons or whitespace)
MY_MAC=$(cat /sys/class/net/$IFACE/address | tr -d ':' | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

# Scan for master node
MASTER_IP=""
for ip in $(seq 1 254); do
    try_ip="192.168.2.$ip"  # Adjust to your subnet!
    if timeout 0.5 bash -c "</dev/tcp/$try_ip/8080" 2>/dev/null; then
        if curl -s "http://$try_ip:8080/join" | grep "microk8s join" >/dev/null; then
            MASTER_IP="$try_ip"
            break
        fi
    fi
done

if [ -n "$MASTER_IP" ]; then
    echo "Found master at $MASTER_IP. Joining..."
    JOIN_CMD=$(curl -s http://$MASTER_IP:8080/join | grep 'microk8s join')
    sudo $JOIN_CMD
    exit 0
fi

echo "No master found. Running leader election..."

# Install arp-scan if needed
if ! command -v arp-scan &> /dev/null; then
    sudo apt-get update && sudo apt-get install -y arp-scan
fi

# ARP scan for MACs (normalize to lowercase, no colons or whitespace)
OTHER_MACS=$(sudo arp-scan --interface=$IFACE --localnet | awk '{print $2}' | tr -d ':' | tr '[:upper:]' '[:lower:]' | grep -E "^[0-9a-f]{12}$")
ALL_MACS=$(echo -e "$MY_MAC\n$OTHER_MACS" | sort | uniq)
LEADER_MAC=$(echo "$ALL_MACS" | sort | head -n1 | tr -d '[:space:]')

# Debug output!
echo "DEBUG: MY_MAC: $MY_MAC"
echo "DEBUG: OTHER_MACS: $OTHER_MACS"
echo "DEBUG: ALL_MACS: $ALL_MACS"
echo "DEBUG: LEADER_MAC: $LEADER_MAC"

if [ "$MY_MAC" = "$LEADER_MAC" ]; then
    echo "Elected master. Initializing MicroK8s..."
    if ! snap list | grep -q microk8s; then
        sudo snap install microk8s --classic
    fi
    sudo microk8s start
    sudo microk8s enable dns storage
    nohup python3 "$JOIN_SERVER_SCRIPT" > /var/log/serve-join.log 2>&1 &
    exit 0
else
    echo "Not master, will retry in 10s..."
    sleep 10
    exec $0
fi
