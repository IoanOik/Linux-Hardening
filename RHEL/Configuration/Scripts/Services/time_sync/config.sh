#!/usr/bin/env bash

#####################################
# This script ensures that Chrony is installed and properly configured for time synchronization.
# It also checks that Chrony is not run as the root user.
#####################################

output=()

# Ensure time synchronization is in use
dnf install chrony &>/dev/null
output+=("$(rpm -q chrony)")

# Ensure chrony is configured
if ! grep -Prsq -- '^\h*(server|pool)\h+[^#\n\r]+' /etc/chrony.conf /etc/chrony.d/; then
    output+=("You need to Add or edit server or pool lines to /etc/chrony.conf or a file in the /etc/chrony.d directory")
fi

# Ensure chrony is not run as the root user
if grep -Psiq -- '^\h*OPTIONS=\"?\h*([^#\n\r]+\h+)?-u\h+root\b' /etc/sysconfig/chronyd; then
    sed -i 's/\(OPTIONS=.*\)-u root\(.*\)/\1\2/' /etc/sysconfig/chronyd
fi

printf "%s\n" "${output[@]}"
