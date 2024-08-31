#!/usr/bin/env bash

##################################
# This script ensures permissions on /etc/ssh/sshd_config
# and inside /etc/ssh/sshd_config.d are configured
#################################

chmod u-x,og-rwx /etc/ssh/sshd_config
chown root:root /etc/ssh/sshd_config
while IFS= read -r -d $'\0' l_file; do
    if [ -e "$l_file" ]; then
        chmod u-x,og-rwx "$l_file"
        chown root:root "$l_file"
    fi
done < <(find /etc/ssh/sshd_config.d -type f -print0 2>/dev/null)
