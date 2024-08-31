#!/usr/bin/env bash

#######################################
# This script checks the message banners that would appear,
# during a user's to log in attemp.
# It is important to not give out critical information,
# because at that phase the user in not yet authenticated.
#######################################

output=()

# Ensure local login warning banner is configured properly

echo "Authorized users only. All activity may be monitored and reported." >/etc/issue
output+=("Added local login warning banner")

# Ensure remote login warning banner is configured properly

echo "Authorized users only. All activity may be monitored and reported." >/etc/issue.net
output+=("Added remote login warning banner")

# Ensure access to /etc/motd /etc/issue /etc/issue.net is configured properly
files=("/etc/motd" "/etc/issue" "/etc/issue.net")

for file in "${files[@]}"; do
    chown root:root "$(readlink -e "$file")" &>/dev/null
    chmod u-x,go-wx "$(readlink -e "$file")" &>/dev/null
done

printf "%s\n" "${output[@]}"
