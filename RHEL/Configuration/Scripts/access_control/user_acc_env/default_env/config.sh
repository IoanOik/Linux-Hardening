#!/usr/bin/env bash

##########################################
# This script ensures that '/nologin' is not listed as an available shell in '/etc/shells', removing it if present
# Configures TMOUT, which automatically logs out idle sessions after 15 minutes
# Sets the default user umask for appropriate file creation permissions
##########################################

# Ensure nologin is not listed in /etc/shells
if grep -Psq '^\h*([^#\n\r]+)?\/nologin\b' /etc/shells; then
    sed -i '/^\h*([^#\n\r]+)?\/nologin\b/d' /etc/shells
fi

# Ensure default user shell timeout is configured
printf '%s\n' "# Set TMOUT to 900 seconds" "typeset -xr TMOUT=900" >/etc/profile.d/50-tmout.sh

# Ensure default user umask is configured
if [[ -e "50-systemwide_umask.sh" ]]; then
    echo "umask 027" >"50-systemwide_umask.sh"
else
    printf "%s\n" "umask 027" >"/etc/profile.d/50-systemwide_umask.sh"
fi
