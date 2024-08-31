#!/usr/bin/env bash

################################
# This script sets specific password policies in '/etc/login.defs' using a predefined set of parameters, ensuring consistent password aging and encryption standards.
# It ensures that inactive user accounts are locked after 10 days of inactivity.
################################

declare -A parameters=(
    ["PASS_MAX_DAYS"]='180'
    ["PASS_MIN_DAYS"]='3'
    ["PASS_WARN_AGE"]='7'
    ["ENCRYPT_METHOD"]='SHA512'
)

for param_name in "${!parameters[@]}"; do
    sed -i "/^\s*${param_name}\s\+/c\\${param_name} ${parameters[$param_name]}" /etc/login.defs
done

# Ensure inactive password lock is configured
awk -F: '($2~/^\$.+/) && ($7 > 10 || $7 == "") {system ("chage --inactive 10 " $1)}' /etc/shadow
useradd -D -f 10 &>/dev/null

# Ensure all users last password date was in the past
{
    # Get the current date in seconds since the epoch
    current_date=$(date +%s)

    # Iterate over each user with a hashed password in /etc/shadow
    while IFS= read -r l_user; do
        # Get the last password change date for the user
        l_change_str=$(chage --list "$l_user" | grep '^Last password change' | cut -d: -f2 | grep -v 'never$')

        if [[ -n "$l_change_str" ]]; then
            # Convert the last password change date to seconds since the epoch
            l_change=$(date -d "$l_change_str" +%s)

            # Check if the last password change date is in the future
            if [[ "$l_change" -gt "$current_date" ]]; then
                echo "User: \"$l_user\" last password change was \"$l_change_str\""
            fi
        fi
    done < <(awk -F: '$2~/^\$.+\$/{print $1}' /etc/shadow)
}
