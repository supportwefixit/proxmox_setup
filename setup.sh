#!/bin/bash

# Prompt the user for new server information
read -p "Enter the new IP address of the server (10.10.10.10): " new_ip
read -p "Enter the new netmask of the server (255.255.255.0): " new_netmask
read -p "Enter the new gateway of the server (10.10.10.1): " new_gateway
read -p "Enter the new hostname of the server (pve1): " new_hostname
read -p "Enter the new domain for the server (example.com): " new_domain

# Update /etc/network/interfaces
sed -i "/^\\taddress /s/\\(.* \\).*/\\1$new_ip/" /etc/network/interfaces
sed -i "/^\\tnetmask /s/\\(.* \\).*/\\1$new_netmask/" /etc/network/interfaces
sed -i "/^\\tgateway /s/\\(.* \\).*/\\1$new_gateway/" /etc/network/interfaces

# Update /etc/hosts
sed -i "2s/.*/$new_ip\t$new_hostname.$new_domain\t$new_hostname/" /etc/hosts

# Update /etc/hostname
echo "$new_hostname" > /etc/hostname

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

# Restart network interfaces
echo "Restarting network interfaces... "
ifdown vmbr0
ifup vmbr0
echo "Complete"

# Restart network services
echo "Restarting network services... "
systemctl restart networking
echo "Complete"

# Prompt for Updates
read -p "Do you want the server to update all packages now (y/n)? " update_answer
if [[ $update_answer =~ ^[Yy]$ ]]; then
  echo "System updating. Please wait..."
  apt-get update > /dev/null
  apt-get upgrade -y > /dev/null
  echo "Updates Complete"
else
  echo "Updates skipped... Moving on"
fi

# Remove Proxmox Subscription nag
echo "Removing Proxmox Subscription nag - METHOD 1... "
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
echo "Complete"

# Remove Proxmox Subscription nag
echo "Removing Proxmox Subscription nag - METHOD 2... "
wget -q -O rem_proxmox_popup.sh 'https://gist.github.com/tavinus/08a63e7269e0f70d27b8fb86db596f0d/raw/' && chmod +x rem_proxmox_popup.sh
./rem_proxmox_popup.sh
echo "Complete"

# Update CT Template list
echo "Updating CT Template list... "
pveam update > /dev/null
echo "Complete"

# Prompt for reboot
read -p "Do you want to reboot the server now (y/n)? " reboot_answer
if [[ $reboot_answer =~ ^[Yy]$ ]]; then
  reboot
else
  echo "Changes will take effect after the next reboot."
fi
