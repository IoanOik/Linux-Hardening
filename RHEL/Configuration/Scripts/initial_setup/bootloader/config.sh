#!/usr/bin/env bash

######################
# Bootloader configuration script
######################
output=()

# Ensure bootloader password is set
l_grub_password_file="$(find /boot -type f -name 'user.cfg' ! -empty)"
if [ -f "$l_grub_password_file" ]; then
    if grep -Eq -- '^GRUB2_PASSWORD=.{10,}' "$l_grub_password_file"; then
        output+=("Grub password is set")
    else
        grub2-setpassword
    fi
else
    grub2-setpassword
fi

# Ensure access to bootloader config is configured

if [[ -f /boot/grub2/grub.cfg ]]; then
    chown root:root /boot/grub2/grub.cfg
    chmod u-x,go-rwx /boot/grub2/grub.cfg
fi

if [[ -f /boot/grub2/grubenv ]]; then
    chown root:root /boot/grub2/grubenv
    chmod u-x,go-rwx /boot/grub2/grubenv
fi

if [[ -f /boot/grub2/user.cfg ]]; then
    chown root:root /boot/grub2/user.cfg
    chmod u-x,go-rwx /boot/grub2/user.cfg
fi

[[ "${#output[@]}" -gt 0 ]] && printf "%s\n" "${output[@]}"
