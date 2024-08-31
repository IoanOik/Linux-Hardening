#!/usr/bin/env bash

##########################
# This script ensures that there is no file/directory
# without owner-group
##########################

{
    audit_pass="" # Initialize variable for correctly configured messages
    audit_fail="" # Initialize variable for incorrectly configured messages
    a_nouser=()   # Array for files/directories without an owner
    a_nogroup=()  # Array for files/directories without a group

    # Paths to exclude from the search
    a_path=(
        ! -path "/run/user/*"
        ! -path "/proc/*"
        ! -path "*/containerd/*"
        ! -path "*/kubelet/pods/*"
        ! -path "*/kubelet/plugins/*"
        ! -path "/sys/fs/cgroup/memory/*"
        ! -path "/var/*/private/*"
    )

    # Loop through each mount point
    while IFS= read -r l_mount; do
        # Find files and directories without an owner or group, excluding specific paths
        while IFS= read -r -d $'\0' l_file; do
            if [ -e "$l_file" ]; then
                while IFS=: read -r l_user l_group; do
                    [ "$l_user" = "UNKNOWN" ] && a_nouser+=("$l_file")   # Add to array if owner is unknown
                    [ "$l_group" = "UNKNOWN" ] && a_nogroup+=("$l_file") # Add to array if group is unknown
                done < <(stat -Lc '%U:%G' "$l_file")
            fi
        done < <(find "$l_mount" -xdev \( "${a_path[@]}" \) \( -type f -o -type d \) \( -nouser -o -nogroup \) -print0 2>/dev/null)
    done < <(findmnt -Dkerno fstype,target | awk '($1 !~ /^\s*(nfs|proc|smb|vfat|iso9660|efivarfs|selinuxfs)/ && $2 !~ /^\/run\/user\//){print $2}')

    # Check if there are any files or directories without an owner
    if ! ((${#a_nouser[@]} > 0)); then
        audit_pass="$audit_pass\n - No files or directories without an owner exist on the local filesystem."
    else
        audit_fail="$audit_fail\n - There are \"$(printf '%s' "${#a_nouser[@]}")\" unowned files or directories on the system.\n - The following is a list of unowned files and/or directories:\n$(printf '%s\n' "${a_nouser[@]}")\n - end of list"
    fi

    # Check if there are any files or directories without a group
    if ! ((${#a_nogroup[@]} > 0)); then
        audit_pass="$audit_pass\n - No files or directories without a group exist on the local filesystem."
    else
        audit_fail="$audit_fail\n - There are \"$(printf '%s' "${#a_nogroup[@]}")\" ungrouped files or directories on the system.\n - The following is a list of ungrouped files and/or directories:\n$(printf '%s\n' "${a_nogroup[@]}")\n - end of list"
    fi

    # Clean up arrays
    unset a_path a_nouser a_nogroup

    # Output results
    if [ -z "$audit_fail" ]; then
        echo -e "\n- Audit Result:\n ** PASS **\n - * Correctly configured * :\n$audit_pass\n"
    else
        echo -e "\n- Audit Result:\n ** FAIL **\n - * Reasons for audit failure * :\n$audit_fail"
        [ -n "$audit_pass" ] && echo -e "\n- * Correctly configured * :\n$audit_pass\n"
    fi
}
