#!/usr/bin/env bash

#######################
# This script ensures that auditd various aspects is properly configured.
# If a mis-configuration is found, the corresponding
# messages get prompted
#######################

# Ensure auditd packages are installed
if ! rpm -q audit audit-libs &>/dev/null; then
    dnf install -y audit audit-libs &>/dev/null
fi

# Ensure auditing for processes that start prior to auditd is enabled
if ! grubby --info=ALL | grep -Poq '\baudit=1\b'; then
    grubby --update-kernel ALL --args 'audit=1' &>/dev/null
    echo 'Edit /etc/default/grub and add audit=1 to the GRUB_CMDLINE_LINUX= line'
fi

# Ensure audit_backlog_limit is sufficient
if ! grubby --info=ALL | grep -Poq "\baudit_backlog_limit=8192\b"; then
    grubby --update-kernel ALL --args 'audit_backlog_limit=8192' &>/dev/null
    echo 'Edit /etc/default/grub and add udit_backlog_limit=8192 to the GRUB_CMDLINE_LINUX= line'
fi

# Ensure auditd service is enabled and active
systemctl unmask auditd &>/dev/null
systemctl enable auditd &>/dev/null
systemctl start auditd &>/dev/null

# Ensure auditd sends logs to syslog
if ! rpm -q audispd-plugins &>/dev/null; then
    dnf install -y audispd-plugins &>/dev/null
fi
sed -i '/^active/c\active = yes' '/etc/audit/plugins.d/syslog.conf'
sed -i '/^write_logs/c\write_logs = no' '/etc/audit/auditd.conf'

# configure auditd rules
cat 'obrela_rules.txt' >'/etc/audit/rules.d/audit.rules'
augenrules --load &>/dev/null
