#!/usr/bin/env bash

#######################
# This script checks and fixes the public and private 
# ssh key file's permissions
#######################

# Initialize output variables
output_summary=""
output_issues=""

# Define permission mask and maximum permission based on it
permission_mask="0177"
max_permission="$(printf '%o' $((0777 & ~permission_mask)))" # 0600

# Function to fix file access issues
fix_file_access() {
    while IFS=: read -r file_mode file_owner file_group; do
        file_issues=""

        # Check if the file's mode is too permissive
        if [ $((file_mode & permission_mask)) -gt 0 ]; then
            file_issues="$file_issues\n - Mode: \"$file_mode\" should be mode: \"$max_permission\" or more restrictive"
            file_issues="$file_issues\n - Updating to mode: \"$max_permission\""
            chmod "$max_permission" "$file"
        fi

        # Check if the file is not owned by root
        if [ "$file_owner" != "root" ]; then
            file_issues="$file_issues\n - Owned by: \"$file_owner\" should be owned by \"root\""
            file_issues="$file_issues\n - Changing ownership to \"root\""
            chown root "$file"
        fi

        # Check if the file's group owner is not root
        if [ "$file_group" != "root" ]; then
            file_issues="$file_issues\n - Owned by group \"$file_group\" should be group owned by: \"root\""
            file_issues="$file_issues\n - Changing group ownership to \"root\""
            chgrp root "$file"
        fi

        # Add the file's issues to the output if any were found
        if [ -n "$file_issues" ]; then
            output_issues="$output_issues\n - File: \"$file\"$file_issues"
        else
            output_summary="$output_summary\n - File: \"$file\"\n - Correct: mode: \"$file_mode\", owner: \"$file_owner\", and group owner: \"$file_group\" configured"
        fi
    done < <(stat -Lc '%#a:%U:%G' "$file")
}

# Main loop to process each file found in /etc/ssh
while IFS= read -r -d $'\0' file; do
    if ssh-keygen -lf "$file" &>/dev/null; then
        if file "$file" | grep -Piq -- '\bopenssh\h+([^#\n\r]+\h+)?(public|private)\h+key\b'; then
            fix_file_access
        fi
    fi
done < <(find -L /etc/ssh -xdev -type f -print0 2>/dev/null)

# Output the results
if [ -z "$output_issues" ]; then
    echo -e "\n- No access changes required\n"
else
    echo -e "\n- Remediation results:\n$output_issues\n"
fi
