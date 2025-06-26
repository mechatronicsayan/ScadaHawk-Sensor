#!/bin/bash

# Function to configure DHCP mgmt only
configure_dynamic_only_management() {

  sudo ip route flush table enp0s3
  sudo ip route flush table enp0s10
  sudo ip rule flush
  # Use netplan to set DHCP for enp0s3
  sudo cat << EOF > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: yes
      optional: true 
    enp0s8:
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s9:
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s10:
      dhcp4: no
      dhcp6: no
      optional: true
EOF

  sudo netplan apply
  echo "Configured DHCP for Management Interface and Deception Interface is set as additional sniffing interface"
}

#Function to configure DHCP mgmt and static deception
configure_dynamic_management_static_deception() {
  
  echo "IP configuration for Deception Interface (enp0s10)"
  read -p  "Enter Static IP address: " ip_address_deception
  read -p "Enter Gateway IP address: " gateway_deception

  sudo ip route flush table enp0s3
  sudo ip route flush table enp0s10
  sudo ip rule flush
  # Use netplan to set DHCP for enp0s3 and static for enp0s10
  sudo cat << EOF > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: yes
      optional: true 
    enp0s8:
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s9:
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s10:
      addresses: [$ip_address_deception/24]
      routes:
        - to: 0.0.0.0/0
          via: $gateway_deception
          metric: 200
      nameservers:
        addresses:
          - 8.8.8.8 
EOF

  sudo netplan apply
  # Configure routing table for enp0s10
  echo "1 enp0s10" | sudo tee -a /etc/iproute2/rt_tables
  sudo ip route add 0.0.0.0/0 via $gateway_deception dev enp0s10 table enp0s10
  sudo ip rule add from $ip_address_deception table enp0s10
  echo "Configured Static IP: $ip_address_deception, Gateway: $gateway_deception for Deception Interface"
}

# Function to configure Static IP for mgmt only
configure_static_only_management() {
  echo "IP configuration for Management Interface (enp0s3)"  
  # Read user input for IP and Gateway
  read -p "Enter Static IP address: " ip_address
  read -p "Enter Default Gateway: " gateway
  
  sudo ip route flush table enp0s3
  sudo ip route flush table enp0s10
  sudo ip rule flush
  # Create netplan config with static IP details
  sudo cat << EOF > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      addresses: [$ip_address/24]
      routes:
        - to: 0.0.0.0/0
          via: $gateway
          metric: 100
      nameservers:
        addresses:
          - 8.8.8.8  
    enp0s8:  # Keep enp0s8 up without IPv4/IPv6
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s9:  # Keep enp0s9 up without IPv4/IPv6
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s10:  # Keep enp0s10 up without IPv4/IPv6
      dhcp4: no
      dhcp6: no
      optional: true
EOF

  # Apply netplan configuration
  sudo netplan apply

  # Configure routing table for enp0s3
  echo "1 enp0s3" | sudo tee -a /etc/iproute2/rt_tables
  sudo ip route add 0.0.0.0/0 via $gateway dev enp0s3 table enp0s3
  sudo ip rule add from $ip_address table enp0s3

  echo "Configured Static IP: $ip_address, Gateway: $gateway for Management Interface and Deception Interface is set as additional sniffing interface"
}

#Configure static IP for mgmt and deception
configure_static_management_static_deception() {
  echo "IP configuration for Management Interface (enp0s3)"
  read -p "Enter Static IP address: " ip_address
  read -p "Enter Default Gateway: " gateway
  echo "IP configuration for Deception Interface (enp0s10)"
  read -p  "Enter Static IP address: " ip_address_deception
  read -p "Enter Gateway IP address: " gateway_deception

  sudo ip route flush table enp0s3
  sudo ip route flush table enp0s10
  sudo ip rule flush
  # Create netplan config with static IP details
  sudo cat << EOF > /etc/netplan/00-installer-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      addresses: [$ip_address/24]
      routes:
        - to: 0.0.0.0/0
          via: $gateway
          metric: 100
      nameservers:
        addresses:
          - 8.8.8.8  
    enp0s8:  # Keep enp0s8 up without IPv4/IPv6
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s9:  # Keep enp0s9 up without IPv4/IPv6
      dhcp4: no
      dhcp6: no
      optional: true
    enp0s10:
      addresses: [$ip_address_deception/24]
      routes:
        - to: 0.0.0.0/0
          via: $gateway_deception
          metric: 200
      nameservers:
        addresses:
          - 8.8.8.8  
EOF

  # Apply netplan configuration
  sudo netplan apply

  # Configure routing tables for enp0s3 and enp0s10
  echo "1 enp0s3" | sudo tee -a /etc/iproute2/rt_tables
  sudo ip route add 0.0.0.0/0 via $gateway dev enp0s3 table enp0s3
  sudo ip rule add from $ip_address table enp0s3

  echo "2 enp0s10" | sudo tee -a /etc/iproute2/rt_tables
  sudo ip route add 0.0.0.0/0 via $gateway_deception dev enp0s10 table enp0s10
  sudo ip rule add from $ip_address_deception table enp0s10

  echo "Configured Static IP: $ip_address, Gateway: $gateway for Management Interface"
  echo "Configured Static IP: $ip_address_deception, Gateway: $gateway_deception for Deception Interface"
}

# Main Menu
echo "===NetworkHawk Configuration Manager==="
echo "Choose IP configuration for Management Interface and Deception Interface:"
echo "1. Automatic (DHCP) IP for Management Interface and Deception Interface configuration"
echo "2. Static IP for Management Interface and Deception Interface configuration"
read -p "Enter your choice (1 or 2): " choice

# Handle user choice
if [ "$choice" -eq 1 ]; then
  read -p "Do you want to configure static IP for Deception Interface: (y/n):" flag
  if [ "$flag" = "n" ]; then
    echo "You can use the Deception Interface as additional sniffing interface."
    configure_dynamic_only_management
  else
    configure_dynamic_management_static_deception
  fi
elif [ "$choice" -eq 2 ]; then
  read -p "Do you want to configure static IP for Deception Interface: (y/n):" flag
  if [ "$flag" = "y" ]; then
    configure_static_management_static_deception
  else
    echo "You can use the Deception Interface as additional sniffing interface."
    configure_static_only_management
  fi
else
  echo "Invalid choice!"
fi

# Countdown before reboot
echo "System will reboot in:"
for i in {3..1}; do
  echo -ne "\r$i "
  sleep 1
done
echo -ne "Rebooting now.\n"

sudo reboot