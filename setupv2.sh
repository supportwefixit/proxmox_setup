#!/bin/bash

loading_animation() {
  local pid=$1
  local spin='. . . . .'
  local delay='0.2'

  while kill -0 $pid 2>/dev/null; do
    for i in $spin; do
      printf "\r%s" "$i"
      sleep $delay
      printf "\r "
      sleep $delay
    done
  done
  printf "\r"
}

# Network Update
read -p "Do you want to enter new network details? (y/n): " network_update
if [[ $network_update =~ ^[Yy]$ ]]; then
  read -p "Enter the new IP address of the server (10.10.10.10): " new_ip
  read -p "Enter the new gateway of the server (10.10.10.1): " new_gateway

  sed -i "/^\\taddress /s/\\(.* \\).*/\\1$new_ip/" /etc/network/interfaces
  sed -i "/^\\tgateway /s/\\(.* \\).*/\\1$new_gateway/" /etc/network/interfaces
else
  echo "Skipping network details update... Moving on"
fi

# FQDN Update
read -p "Do you want to enter new FQDN details? (y/n): " fqdn_update
if [[ $fqdn_update =~ ^[Yy]$ ]]; then
  read -p "Enter the new hostname of the server (pve1): " new_hostname
  read -p "Enter the new domain for the server (example.com): " new_domain

  # Check if a new IP address is entered, if not, retain the current IP in /etc/hosts
  if [[ -n $new_ip ]]; then
    sed -i "2s/.*/$new_ip\t$new_hostname.$new_domain\t$new_hostname/" /etc/hosts
  else
    current_ip=$(grep -E "^\s*[^#]" /etc/hosts | awk '{print $1}' | head -n 1)
    sed -i "2s/.*/$current_ip\t$new_hostname.$new_domain\t$new_hostname/" /etc/hosts
  fi

  echo "$new_hostname.$new_domain" > /etc/hostname
fi

# Rewrite /etc/apt/sources.list file
echo "Rewriting /etc/apt/sources.list... "
echo "deb http://ftp.au.debian.org/debian bullseye main contrib
deb http://ftp.au.debian.org/debian bullseye-updates main contrib
# security updates
deb http://security.debian.org bullseye-security main contrib
deb http://download.proxmox.com/debian/pve bullseye pve-no-subscription" > /etc/apt/sources.list
echo "Complete"

# Rewrite /etc/apt/sources.list.d/pve-enterprise.list file
echo "Rewriting enterprise sources list... "
echo "#deb https://enterprise.proxmox.com/debian/pve bullseye pve-enterprise" > /etc/apt/sources.list.d/pve-enterprise.list
echo "Complete"

# Prompt for Updates
read -p "Do you want the server to update all packages now (y/n)? " update_answer
if [[ $update_answer =~ ^[Yy]$ ]]; then
  # Run update and upgrade in the background
  {
    apt-get update > /dev/null
    apt-get upgrade -y > /dev/null
  } &

  # Create a PID for the background process
  pid=$!

  loading_animation $pid

  echo "Updates Complete"
else
  echo "Updates skipped... Moving on"
fi

# Update CT Template list
echo "Updating CT Template list... "
pveam update > /
null
echo "Complete"

# Remove Proxmox Subscription nag - METHOD 1
echo "Removing Proxmox Subscription nag - METHOD 1... "
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Remove Proxmox Subscription nag - METHOD 2
echo "Removing Proxmox Subscription nag - METHOD 2... "
SEDBIN="$(which sed)"
TGTPATH='/usr/share/perl5/PVE/API2'
TGTFILE='Subscription.pm'
sed -i.bak 's/NotFound/Active/g' "$TGTPATH/$TGTFILE"
sed -i.bak 's/notfound/active/g' "$TGTPATH/$TGTFILE"
echo "Complete"

# Ask to restart the server
read -p "Do you want to reboot the server now (y/n)? " reboot_answer

# Restart the server
if [[ $reboot_answer =~ ^[Yy]$ ]]; then
  reboot
else
  echo "All changes will take effect after the next reboot or service restart."
fi
