#!/usr/bin/env bash

########################
# This script ensures that the system's integrity is maintained by verifying file integrity
# using AIDE (Advanced Intrusion Detection Environment).
########################

# Ensure AIDE is installed
if ! rpm -q aide &>/dev/null; then
    dnf -y install aide &>/dev/null
    echo "Intitializing aide... "
    aide --init
    mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
fi

rpm -q aide

# Ensure filesystem integrity is regularly checked
echo "Schedule a cron job or a systemd timer for Aide"

# Ensure cryptographic mechanisms are used to protect the integrity of audit tools
printf '\n%s\n' "# Audit Tools" \
    "$(readlink -f /sbin/auditctl) p+i+n+u+g+s+b+acl+xattrs+sha512" \
    "$(readlink -f /sbin/auditd) p+i+n+u+g+s+b+acl+xattrs+sha512" \
    "$(readlink -f /sbin/ausearch) p+i+n+u+g+s+b+acl+xattrs+sha512" \
    "$(readlink -f /sbin/aureport) p+i+n+u+g+s+b+acl+xattrs+sha512" \
    "$(readlink -f /sbin/autrace) p+i+n+u+g+s+b+acl+xattrs+sha512" \
    "$(readlink -f /sbin/augenrules) p+i+n+u+g+s+b+acl+xattrs+sha512" >>/etc/aide.conf

