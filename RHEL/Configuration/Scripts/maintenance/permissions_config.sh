#!/usr/bin/env bash

##############################
# This script sets the permissions and ownership for critical system files
# to ensure proper access control and security.
##############################

# Files to configure
declare -A file_permissions=(
    ["/etc/passwd"]='644'
    ["/etc/passwd-"]='644'
    ["/etc/group"]='644'
    ["/etc/group-"]='644'
    ["/etc/shadow"]='000'
    ["/etc/shadow-"]='000'
    ["/etc/gshadow-"]='000'
    ["/etc/shells"]='644'
    ["/etc/gshadow"]='000'
    ["/etc/security/opasswd"]='600'
    ["/etc/security/opasswd.old"]='600'
)

for file in "${!file_permissions[@]}"; do
    if [[ -e "$file" ]]; then
        chmod "${file_permissions[$file]}" "$file" &>/dev/null
        chown 'root:root' "$file" &>/dev/null
    fi
done

for file in "${!file_permissions[@]}"; do
    stat -L -c '%n Access: (%A/%a) Owner: (%U/%u) Group: (%G/%g) ' "${file}"
done
