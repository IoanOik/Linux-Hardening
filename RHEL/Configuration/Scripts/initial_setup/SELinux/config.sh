#!/usr/bin/env bash

########################
# This script aims for the proper configuration of SELinux
########################

output=()

# Installing the package

dnf -y install libselinux &>/dev/null
output+=("$(rpm -q libselinux)")

# Bootloader config for SELinux

if grep -Pq '(selinux|enforcing)=0\b' < <(grubby --info=ALL); then
    grubby --update-kernel ALL --remove-args "selinux=0 enforcing=0" &>/dev/null
    if grep -Prsq -- '\h*([^#\n\r]+\h+)?kernelopts=([^#\n\r]+\h+)?(selinux|enforcing)=0\b' /boot/grub2 /boot/efi; then
        # overwrite the faulty files with the kernel running configuration options
        grub2-mkconfig -o "$(grep -Prsl -- '\h*([^#\n\r]+\h+)?kernelopts=([^#\n\r]+\h+)?(selinux|enforcing)=0\b' /boot/grub2 /boot/efi)"
        output+=("re-configured selinux parameters inside bootloader")
    fi
fi

# Ensure SELinux policy is configured

if ! grep -Eq '^\s*SELINUXTYPE=(targeted|mls)\b' /etc/selinux/config; then
    sed -i '/SELINUXTYPE=/c\SELINUXTYPE=targeted' /etc/selinux/config
    output+=("Changed policy to 'targeted'")
fi

# Ensure SELinux mode is 'enforcing'

if ! grep -Eiq '^\s*SELINUX=enforcing' /etc/selinux/config; then
    sed -i '/SELINUX=/c\SELINUX=enforcing' /etc/selinux/config
    setenforce 1
    output+=("Changed mode to 'enforced'")
fi

# Ensure no unconfined services exist

if grep -q 'unconfined_service_t' < <(ps -eZ); then
    output+=("Found some unconfined services:")
    # shellcheck disable=SC2009
    readarray -t services < <(ps -eZ | grep -i 'unconfined_service_t')
    output+=("${services[@]}")
fi

# Ensure the MCS Translation Service (mcstrans) is not installed

dnf -y remove mcstrans &>/dev/null

# Ensure SETroubleshoot is not installed

dnf -y remove setroubleshoot &>/dev/null

# Print the output
[[ "${#output[@]}" -gt 0 ]] && printf "%s\n" "${output[@]}"
