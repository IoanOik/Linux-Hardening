#!/usr/bin/env bash

########################
# This script checks for the appropriate
# permission settings on world writable files and directories
########################

{
    audit_pass=""   # Initialize variable for correctly configured messages
    audit_fail=""   # Initialize variable for incorrectly configured messages
    l_smask='01000' # Sticky bit mask

    a_file=() # Array for world-writable files
    a_dir=()  # Array for world-writable directories without the sticky bit

    # Paths to exclude from the search
    a_path=(
        ! -path "/run/user/*"
        ! -path "/proc/*"
        ! -path "*/containerd/*"
        ! -path "*/kubelet/pods/*"
        ! -path "*/kubelet/plugins/*"
        ! -path "/sys/*"
        ! -path "/snap/*"
    )

    # Loop through each mount point
    while IFS= read -r l_mount; do
        # Find world-writable files and directories, excluding specific paths
        while IFS= read -r -d $'\0' l_file; do
            if [ -e "$l_file" ]; then
                [ -f "$l_file" ] && a_file+=("$l_file") # Add world-writable files to the array
                if [ -d "$l_file" ]; then               # Check directories for sticky bit
                    l_mode="$(stat -Lc '%#a' "$l_file")"
                    [ ! $((l_mode & l_smask)) -gt 0 ] && a_dir+=("$l_file") # Add directories without sticky bit
                fi
            fi
        done < <(find "$l_mount" -xdev \( "${a_path[@]}" \) \( -type f -o -type d \) -perm -0002 -print0 2>/dev/null)
    done < <(findmnt -Dkerno fstype,target | awk '($1 !~ /^\s*(nfs|proc|smb|vfat|iso9660|efivarfs|selinuxfs)/ && $2 !~ /^(\/run\/user\/|\/tmp|\/var\/tmp)/){print $2}')

    # Check if there are any world-writable files
    if ! ((${#a_file[@]} > 0)); then
        audit_pass="$audit_pass\n - No world writable files exist on the local filesystem."
    else
        audit_fail="$audit_fail\n - There are \"$(printf '%s' "${#a_file[@]}")\" world writable files on the system.\n - The following is a list of world writable files:\n$(printf '%s\n' "${a_file[@]}")\n - end of list\n"
    fi

    # Check if there are any world-writable directories without the sticky bit
    if ! ((${#a_dir[@]} > 0)); then
        audit_pass="$audit_pass\n - Sticky bit is set on world writable directories on the local filesystem."
    else
        audit_fail="$audit_fail\n - There are \"$(printf '%s' "${#a_dir[@]}")\" world writable directories without the sticky bit on the system.\n - The following is a list of world writable directories without the sticky bit:\n$(printf '%s\n' "${a_dir[@]}")\n - end of list\n"
    fi

    # Clean up arrays
    unset a_path a_file a_dir

    # Output results
    if [ -z "$audit_fail" ]; then
        echo -e "\n- Audit Result:\n ** PASS **\n - * Correctly configured * :\n$audit_pass\n"
    else
        echo -e "\n- Audit Result:\n ** FAIL **\n - * Reasons for audit failure * :\n$audit_fail"
        [ -n "$audit_pass" ] && echo -e "- * Correctly configured * :\n$audit_pass\n"
    fi
}
