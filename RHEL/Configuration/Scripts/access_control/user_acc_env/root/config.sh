#!/usr/bin/env bash

# This script performs the following tasks:
# 1. **Root PATH Integrity Check**:
#    - Ensures that the root user's PATH environment variable is correctly configured, avoiding potential security risks.
#    - Checks for and reports any empty directories, current working directory entries, or inappropriate permissions/ownership in the root PATH.
# 2. **System-wide Umask Configuration**:
#    - Sets a restrictive default umask to control the default file creation permissions system-wide.
# 3. **System Account Shell Validation**:
#    - Ensures that system accounts do not have a valid login shell unless explicitly allowed, reducing the risk of unauthorized access.
# 4. **Account Locking**:
#    - Locks accounts without a valid login shell to further secure system accounts.

# Ensure root path integrity
{
    # Initialize the output variable
    audit_results=""

    # Define the permission mask and calculate the maximum permissible file mode
    permission_mask="0022"
    max_permission="$(printf '%o' $((0777 & ~permission_mask)))"

    # Get the root user's PATH environment variable
    root_path="$(sudo -Hiu root env | grep '^PATH' | cut -d= -f2)"

    # Split the PATH into an array of directory locations
    unset path_locations && IFS=":" read -ra path_locations <<<"$root_path"

    # Check for an empty directory in the PATH (indicated by "::")
    grep -q "::" <<<"$root_path" && audit_results="$audit_results\n - Root's PATH contains an empty directory (::)"

    # Check for a trailing colon in the PATH (indicating an empty entry at the end)
    grep -Pq ":\h*$" <<<"$root_path" && audit_results="$audit_results\n - Root's PATH contains a trailing colon (:)"

    # Check if the current working directory (.) is in the PATH
    grep -Pq '(\h+|:)\.(:|\h*$)' <<<"$root_path" && audit_results="$audit_results\n - Root's PATH contains the current working directory (.)"

    # Iterate through each directory in the PATH
    while read -r path_dir; do
        if [ -d "$path_dir" ]; then
            # Check the ownership and permissions of each directory
            while read -r file_mode file_owner; do
                # Verify if the directory is owned by root
                [ "$file_owner" != "root" ] && audit_results="$audit_results\n - Directory: \"$path_dir\" is owned by: \"$file_owner\" should be owned by \"root\""

                # Verify if the directory's permissions are correct
                [ $((file_mode & permission_mask)) -gt 0 ] && audit_results="$audit_results\n - Directory: \"$path_dir\" has mode: \"$file_mode\" and should have mode: \"$max_permission\" or more restrictive"
            done <<<"$(stat -Lc '%#a %U' "$path_dir")"
        else
            # Report if the path entry is not a directory
            audit_results="$audit_results\n - \"$path_dir\" is not a directory"
        fi
    done <<<"$(printf "%s\n" "${path_locations[@]}")"

    # Output the audit results
    if [ -z "$audit_results" ]; then
        echo -e "\n- Audit Result:\n *** PASS ***\n - Root's PATH is correctly configured\n"
    else
        echo -e "\n- Audit Result:\n ** FAIL **\n - * Reasons for audit failure * :\n$audit_results\n"
    fi
}

# Ensure system umask is configured
printf"%s\n" 'umask 0027' >>'root/.bashrc'

# Ensure system accounts do not have a valid login shell

{
    # Generate a regular expression pattern of valid login shells from /etc/shells,
    # excluding "nologin". This pattern will be used to identify valid shells.
    valid_shells_pattern="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells | sed -rn '/^\//{s,/,\\\\/,g;p}' | paste -s -d '|' -))$"

    # Minimum UID for regular users from /etc/login.defs
    uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs)

    # Use awk to find and modify users in /etc/passwd based on specific conditions
    awk -v pat="$valid_shells_pattern" -F: '
    {
        # Check if UID is less than UID_MIN or is equal to 65534 (nfsnobody)
        if ($3 >= '"$uid_min"' && $3 != 65534) {
            next
        }

        # Exclude certain system accounts
        if ($1 ~ /^(root|halt|sync|shutdown|nfsnobody)$/) {
            next
        }

        # Check if the shell is valid according to the pattern
        if ($NF !~ pat) {
            next
        }

        # If all conditions are met, change the user shell to nologin
        system( "usermod -s '"$(command -v nologin)"' " $1)
    }
    ' /etc/passwd
}

# Ensure accounts without a valid login shell are locked
{
    # Generate a regular expression pattern of valid login shells from /etc/shells,
    # excluding "nologin". This pattern will be used to identify valid shells.
    l_valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells | sed -rn '/^\//{s,/,\\\\/,g;p}' | paste -s -d '|' -))$"

    # Iterate over each user returned by the inner awk command
    while IFS= read -r l_user; do

        # Check if the user's password status does not start with "L" (not locked)
        passwd -S "$l_user" | awk '$2 !~ /^L/ {system ("usermod -L " $1)}'

    done < <(awk -v pat="$l_valid_shells" -F: '($1 != "root" && $(NF) !~ pat) { print $1 }' /etc/passwd) # Find users whose shell is not valid according to the pattern and is not "root"
}
