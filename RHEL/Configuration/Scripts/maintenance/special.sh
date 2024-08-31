#!/usr/bin/env bash

###############################
# This script prints all the SUID-SGUID
# files on the sysyem
###############################

{
    audit_pass="" # Initialize variable for correctly configured messages
    audit_fail="" # Initialize variable for incorrectly configured messages
    a_suid=()     # Array for SUID files
    a_sgid=()     # Array for SGID files

    # Loop through each mount point
    while IFS= read -r l_mount; do
        # Find files with SUID or SGID permissions in the mount point
        while IFS= read -r -d $'\0' l_file; do
            if [ -e "$l_file" ]; then
                l_mode="$(stat -Lc '%#a' "$l_file")"
                [ $((l_mode & 04000)) -gt 0 ] && a_suid+=("$l_file") # Add to array if SUID is set
                [ $((l_mode & 02000)) -gt 0 ] && a_sgid+=("$l_file") # Add to array if SGID is set
            fi
        done < <(find "$l_mount" -xdev -type f \( -perm -2000 -o -perm -4000 \) -print0 2>/dev/null)
    done < <(findmnt -Dkerno fstype,target,options | awk '($1 !~ /^\s*(nfs|proc|smb|vfat|iso9660|efivarfs|selinuxfs)/ && $2 !~ /^\/run\/user\// && $3 !~/noexec/ && $3 !~/nosuid/) {print $2}')

    # Check if there are any SUID files
    if ! ((${#a_suid[@]} > 0)); then
        audit_pass="$audit_pass\n - No executable SUID files exist on the system"
    else
        audit_fail="$audit_fail\n - List of \"$(printf '%s' "${#a_suid[@]}")\" SUID executable files:\n$(printf '%s\n' "${a_suid[@]}")\n - end of list -\n"
    fi

    # Check if there are any SGID files
    if ! ((${#a_sgid[@]} > 0)); then
        audit_pass="$audit_pass\n - No SGID files exist on the system"
    else
        audit_fail="$audit_fail\n - List of \"$(printf '%s' "${#a_sgid[@]}")\" SGID executable files:\n$(printf '%s\n' "${a_sgid[@]}")\n - end of list -\n"
    fi

    # Add a recommendation if any SUID/SGID files are found
    if [ -n "$audit_fail" ]; then
        audit_fail="$audit_fail\n- Review the preceding list(s) of SUID and/or SGID files to ensure that no rogue programs have been introduced onto the system.\n"
    fi

    # Clean up arrays
    unset a_suid a_sgid

    # Output results
    if [ -z "$audit_fail" ]; then
        echo -e "\n- Audit Result:\n$audit_pass\n"
    else
        echo -e "\n- Audit Result:\n$audit_fail\n"
        [ -n "$audit_pass" ] && echo -e "$audit_pass\n"
    fi
}
