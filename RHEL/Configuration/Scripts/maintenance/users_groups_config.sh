#!/usr/bin/env bash

#####################################
# This script performs checks and fixes related to user and
# group configurations. It ensures:
# -Users in /etc/passwd have shadowed passwords.
# -Password fields in /etc/shadow are not empty.
# -Groups listed in /etc/passwd exist in /etc/group.
# -There are no duplicate UIDs or GIDs.
# -Usernames and group names are unique.
#####################################

# Ensure accounts in /etc/passwd use shadowed passwords
awk -F: '
BEGIN {found = 0}
{ 
    if ($2 != "x"){
    print "User: \"" $1 "\" is not set to shadowed passwords"
    found = 1
    }
}
END{
if (found > 0){
    exit 1
    }
}
' /etc/passwd

if (($? == 1)); then
    pwconv
fi

# Ensure /etc/shadow password fields are not empty
awk -F: '
{ 
    if ($2 = ""){
    print $1 " does not have a password "
    print "temporary locking the account"
    terminal = "usermod -L " $1
    system(terminal)
    }
}
' /etc/passwd

# Ensure all groups listed in /etc/passwd exist in /etc/group
{
    # Extract unique GIDs from /etc/passwd and /etc/group
    passwd_group_gids=("$(awk -F: '{print $4}' /etc/passwd | sort -u)")
    group_gids=("$(awk -F: '{print $3}' /etc/group | sort -u)")

    # Find GIDs present in /etc/passwd but not in /etc/group
    missing_group_gids=("$(printf '%s\n' "${group_gids[@]}" "${passwd_group_gids[@]}" | sort | uniq -u)")

    # Report users with GIDs that are missing from /etc/group
    while IFS= read -r gid; do
        awk -F: -v gid="$gid" '($4 == gid) {print " - User: \"" $1 "\" has GID: \"" $4 "\" which does not exist in /etc/group"}' /etc/passwd
    done < <(printf '%s\n' "${passwd_group_gids[@]}" "${missing_group_gids[@]}" | sort | uniq -D | uniq)
}

# Check for duplicate UIDs in /etc/passwd and report them
{
    while read -r count uid; do
        if [ "$count" -gt 1 ]; then
            # Report the duplicate UID and the associated usernames
            echo -e "Duplicate UID: \"$uid\" Users: \"$(awk -F: -v uid="$uid" '($3 == uid) {print $1}' /etc/passwd | xargs)\""
        fi
    done < <(cut -d":" -f3 /etc/passwd | sort -n | uniq -c)
}

# Ensure no duplicate GIDs exist
{
    while read -r count gid; do
        if [ "$count" -gt 1 ]; then
            # Report the duplicate GID and the associated group names
            echo -e "Duplicate GID: \"$gid\" Groups: \"$(awk -F: -v gid="$gid" '($3 == gid) {print $1}' /etc/group | xargs)\""
        fi
    done < <(cut -d":" -f3 /etc/group | sort -n | uniq -c)
}

# Ensure no duplicate user names exist
{
    while read -r count username; do
        if [ "$count" -gt 1 ]; then
            # Report the duplicate user name and the associated user names
            echo -e "Duplicate User: \"$username\" Users: \"$(awk -F: -v user="$username" '($1 == user) {print $1}' /etc/passwd | xargs)\""
        fi
    done < <(cut -d":" -f1 /etc/group | sort -n | uniq -c)
}

# Ensure no duplicate group names exist
{
    while read -r count groupname; do
        if [ "$count" -gt 1 ]; then
            # Report the duplicate group name and the associated group names
            echo -e "Duplicate Group: \"$groupname\" Groups: \"$(awk -F: -v group="$groupname" '($1 == group) {print $1}' /etc/group | xargs)\""
        fi
    done < <(cut -d":" -f1 /etc/group | sort -n | uniq -c)
}
