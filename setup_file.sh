#!/bin/bash

sudo apt update || { echo "Failed to update package lists. Aborting."; exit 1; }

# Install Python3 and pip3 (adjust for your package manager if needed)
sudo apt install -y python3 python3-pip || { echo "Failed to install Python3 and pip3. Aborting."; exit 1; }

sudo apt install -y tshark || { echo "Failed to install tshark. Aborting."; exit 1; }

sudo apt install -y dos2unix || { echo "Failed to install tshark. Aborting."; exit 1; }

# Install required Python libraries
sudo pip3 install aiohttp asyncio pyshark websockets==12.0 PyJWT requests paramiko psutil pymodbus==2.5.3 twisted testresources netifaces|| { echo "Failed to install Python libraries. Aborting."; exit 1; }

# Create directory for scripts with error handling
if [[ ! -d /home/scripts ]]; then
  echo "Creating directory /home/scripts"
  sudo mkdir -p /home/scripts || { echo "Failed to create directory /home/scripts. Aborting."; exit 1; }
fi

# Specify the source location of your setup.sh script (modify this line)

sudo cp /home/hawk/deployables/sniffer_hawk_to_server.py /home/scripts/sniffer_hawk_to_server.py || { echo "Failed to copy. Aborting"; exit 1;}
sudo chmod +x /home/scripts/sniffer_hawk_to_server.py

sudo cp /home/hawk/deployables/deception.py /home/scripts/deception.py || { echo "Failed to copy. Aborting"; exit 1;}
sudo chmod +x /home/scripts/deception.py

sudo cp /home/hawk/deployables/credential_management.py /home/scripts/credential_management.py || { echo "Failed to copy. Aborting"; exit 1;}
sudo chmod +x /home/scripts/credential_management.py

# Copy and set permissions for setup.sh (assuming it's a Python script)
sudo cp /home/hawk/deployables/user_setup.sh /home/scripts/user_setup.sh || { echo "Failed to copy setup.sh. Aborting."; exit 1; }
sudo chmod +x /home/scripts/user_setup.sh || { echo "Failed to set permissions for setup.sh. Aborting."; exit 1; }
sudo chmod +x /home/scripts  || { echo "Failed to set permissions for /home/scripts. Aborting."; exit 1; }

# Configure automatic execution of setup.sh (requires elevated privileges)
echo "if [[ ! -f /etc/.user_configured ]]; then" >> /home/hawk/.bashrc || { echo "Failed to modify .bashrc. Aborting."; exit 1; }
echo "  /home/scripts/user_setup.sh" >> /home/hawk/.bashrc || { echo "Failed to modify .bashrc. Aborting."; exit 1; }
echo "fi" >> /home/hawk/.bashrc || { echo "Failed to modify .bashrc. Aborting."; exit 1; }

# Copy the issue file with error handling
sudo cp /home/hawk/deployables/issue /etc/issue || { echo "Failed to copy issue file. Aborting."; exit 1; }

# Copy network_setup.sh with elevated privileges
sudo cp /home/hawk/deployables/network_setup.sh /etc/network_setup.sh || { echo "Failed to copy network_setup.sh. Aborting."; exit 1; }
sudo chmod +x /etc/network_setup.sh || { echo "Failed to set permissions for network_setup.sh. Aborting."; exit 1; }

# Copy sniffer_hawk.service with elevated privileges
sudo cp /home/hawk/deployables/sniffer_hawk.service /etc/systemd/system/sniffer_hawk.service || { echo "Failed to copy sniffer_hawk.service. Aborting."; exit 1; }
sudo chmod +x /etc/systemd/system/sniffer_hawk.service || { echo "Failed to set permissions for sniffer_hawk.service. Aborting."; exit 1; }

# Copy deception.service with elevated privileges
sudo cp /home/hawk/deployables/deception.service /etc/systemd/system/deception.service || { echo "Failed to copy deception.service. Aborting."; exit 1; }
sudo chmod +x /etc/systemd/system/deception.service || { echo "Failed to set permissions for deception.service. Aborting."; exit 1; }

# Reload systemd and enable/start sniffer_hawk.service (requires elevated privileges)
sudo systemctl daemon-reload || { echo "Failed to reload systemd. Aborting."; exit 1; }
sudo systemctl enable sniffer_hawk.service || { echo "Failed to enable sniffer_hawk.service. Aborting."; exit 1; }
sudo systemctl enable deception.service || { echo "Failed to enable deception.service. Aborting."; exit 1; }

# Copy ScadaHawk and set permissions (requires elevated privileges)
sudo cp /home/hawk/deployables/ScadaHawk /usr/local/bin/ScadaHawk || { echo "Failed to copy ScadaHawk. Aborting."; exit 1; }
sudo chmod +x /usr/local/bin/ScadaHawk || { echo "Failed to set permissions for ScadaHawk. Aborting."; exit 1; }

# Copy DeceptionHawk and set permissions (requires elevated privileges)
sudo cp /home/hawk/deployables/DeceptionHawk /usr/local/bin/DeceptionHawk || { echo "Failed to copy DeceptionHawk. Aborting."; exit 1; }
sudo chmod +x /usr/local/bin/DeceptionHawk || { echo "Failed to set permissions for DeceptionHawk. Aborting."; exit 1; }

# Copy NetworkHawk and set permissions (requires elevated privileges)
sudo cp /home/hawk/deployables/NetworkHawk /usr/local/bin/NetworkHawk || { echo "Failed to copy NetworkHawk. Aborting."; exit 1; }
sudo chmod +x /usr/local/bin/NetworkHawk || { echo "Failed to set permissions for NetworkHawk. Aborting."; exit 1; }

# Copy ServerHawk and set permissions (requires elevated privileges)
sudo cp /home/hawk/deployables/ServerHawk /usr/local/bin/ServerHawk || { echo "Failed to copy ServerHawk. Aborting."; exit 1; }
sudo chmod +x /usr/local/bin/ServerHawk || { echo "Failed to set permissions for ServerHawk. Aborting."; exit 1; }

sudo ufw --force enable

sudo ufw allow 502/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp

# Countdown before reboot
echo "System will reboot in:"
for i in {10..1}; do
  echo -ne "\r$i "
  sleep 1
done
echo -ne "Rebooting now.\n"

sudo reboot