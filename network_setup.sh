#!/bin/bash

# Function to validate IP addresses
validate_ip() {
  local ip=$1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ ${BASH_REMATCH[0]} == "$ip" ]]; then
    return 0  # Valid IP
  else
    echo -e "\e[31mInvalid IP address format. Please try again.\e[0m"
    exit 1
  fi
}

# Function to configure DHCP mgmt only
configure_dynamic_only_management() {

  sudo ip route flush dev enp0s3
  sudo ip route flush dev enp0s10
  sudo ip rule flush
  # Use netplan to set DHCP for enp0s3
  sudo tee /etc/netplan/00-installer-config.yaml << EOF > /dev/null
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
  echo -e "\e[32mConfigured DHCP for Management Interface. Deception Interface is set as an additional sniffing interface.\e[0m"
}

# Function to configure DHCP mgmt and static deception
configure_dynamic_management_static_deception() {

  echo "IP configuration for Deception Interface (enp0s10)"
  read -p "Enter Static IP address: " ip_address_deception
  validate_ip "$ip_address_deception"
  read -p "Enter Gateway IP address: " gateway_deception
  validate_ip "$gateway_deception"

  sudo ip route flush dev enp0s3
  sudo ip route flush dev enp0s10
  sudo ip rule flush
  # Use netplan to set DHCP for enp0s3 and static for enp0s10
  sudo tee /etc/netplan/00-installer-config.yaml << EOF > /dev/null
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

  # Prevent duplicate entries in routing table
  grep -q "2 enp0s10" /etc/iproute2/rt_tables || echo "2 enp0s10" | sudo tee -a /etc/iproute2/rt_tables

  sudo ip route add 0.0.0.0/0 via $gateway_deception dev enp0s10 table enp0s10
  sudo ip rule del from $ip_address_deception table enp0s10 2>/dev/null
  sudo ip rule add from $ip_address_deception table enp0s10
  echo -e "\e[32mConfigured Static IP: $ip_address_deception, Gateway: $gateway_deception for Deception Interface.\e[0m"
}

# Function to configure Static IP for mgmt only
configure_static_only_management() {
  echo "IP configuration for Management Interface (enp0s3)"  
  read -p "Enter Static IP address: " ip_address
  validate_ip "$ip_address"
  read -p "Enter Default Gateway: " gateway
  validate_ip "$gateway"

  sudo ip route flush dev enp0s3
  sudo ip route flush dev enp0s10
  sudo ip rule flush

  sudo tee /etc/netplan/00-installer-config.yaml << EOF > /dev/null
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

  # Prevent duplicate entries in routing table
  grep -q "1 enp0s3" /etc/iproute2/rt_tables || echo "1 enp0s3" | sudo tee -a /etc/iproute2/rt_tables

  sudo ip route add 0.0.0.0/0 via $gateway dev enp0s3 table enp0s3
  sudo ip rule del from $ip_address table enp0s3 2>/dev/null
  sudo ip rule add from $ip_address table enp0s3

  echo -e "\e[32mConfigured Static IP: $ip_address, Gateway: $gateway for Management Interface.\e[0m"
}

# Function to configure static IP for mgmt and deception
configure_static_management_static_deception() {
  echo "IP configuration for Management Interface (enp0s3)"
  read -p "Enter Static IP address: " ip_address
  validate_ip "$ip_address"
  read -p "Enter Default Gateway: " gateway
  validate_ip "$gateway"
  echo "IP configuration for Deception Interface (enp0s10)"
  read -p "Enter Static IP address: " ip_address_deception
  validate_ip "$ip_address_deception"
  read -p "Enter Gateway IP address: " gateway_deception
  validate_ip "$gateway_deception"

  sudo ip route flush dev enp0s3
  sudo ip route flush dev enp0s10
  sudo ip rule flush

  sudo tee /etc/netplan/00-installer-config.yaml << EOF > /dev/null
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
  # Prevent duplicate routing table entries
  grep -q "1 enp0s3" /etc/iproute2/rt_tables || echo "1 enp0s3" | sudo tee -a /etc/iproute2/rt_tables
  grep -q "2 enp0s10" /etc/iproute2/rt_tables || echo "2 enp0s10" | sudo tee -a /etc/iproute2/rt_tables

  sudo ip route add 0.0.0.0/0 via $gateway dev enp0s3 table enp0s3
  sudo ip route add 0.0.0.0/0 via $gateway_deception dev enp0s10 table enp0s10

  sudo ip rule del from $ip_address table enp0s3 2>/dev/null
  sudo ip rule del from $ip_address_deception table enp0s10 2>/dev/null
  sudo ip rule add from $ip_address table enp0s3
  sudo ip rule add from $ip_address_deception table enp0s10

  echo -e "\e[32mConfigured static IP for Management and Deception interfaces.\e[0m"
}

# Main Menu
echo "=== NetworkHawk Configuration Manager ==="
echo "1. Automatic (DHCP) IP for Management Interface and Deception Interface"
echo "2. Static IP for Management Interface and Deception Interface"
read -p "Enter your choice (1 or 2): " choice

if [ "$choice" -eq 1 ]; then
  read -p "Configure static IP for Deception Interface? (y/n): " flag
  [[ "$flag" == "n" ]] && configure_dynamic_only_management || configure_dynamic_management_static_deception
elif [ "$choice" -eq 2 ]; then
  read -p "Configure static IP for Deception Interface? (y/n): " flag
  [[ "$flag" == "n" ]] && configure_static_only_management || configure_static_management_static_deception
else
  echo -e "\e[31mInvalid choice!\e[0m Exiting."
  exit 1
fi

# Countdown before reboot
read -p "Reboot required. Reboot now? (y/n): " reboot_choice
if [ "$reboot_choice" = "y" ]; then
  echo -e "Rebooting system in:"
  for i in {3..1}; do
    echo -ne "\r$i "
    sleep 1
  done
  echo -ne "Rebooting now...\n"
  sudo reboot
else
  echo -e "\e[33mPlease reboot manually later to apply changes.\e[0m"
fi
