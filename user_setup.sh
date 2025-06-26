#!/bin/bash

if [[ ! -f /etc/.user_configured ]]; then
  read -p "Enter new username: " new_username
  if id "$new_username" &>/dev/null; then
    echo "User $new_username already exists."
    exit 1
  fi 

  read -p "Enter new hostname: " new_hostname

  sudo useradd -m -s /bin/bash "$new_username"
  sudo passwd $new_username
  sudo usermod -aG ubuntu "$new_username"
  sudo hostnamectl set-hostname "$new_hostname"
  sudo usermod -aG sudo "$new_username"
  sudo cp /etc/skel/.bashrc /home/"$new_username"/
  sudo cp /etc/skel/.profile /home/"$new_username"/
  sudo chown "$new_username":"$new_username" /home/"$new_username"/.bashrc
  sudo chown "$new_username":"$new_username" /home/"$new_username"/.profile


  sudo touch /etc/.user_configured

  echo "User, hostname configuration complete. Please load again with your new credentials."

fi

echo "Setup complete."


su - "$new_username"

