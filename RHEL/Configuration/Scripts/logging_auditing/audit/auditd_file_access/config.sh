#!/usr/bin/env bash

#####################################
# This script is designed to secure the audit log files, configuration files, and audit tools on a Linux system.
# It achieves this by enforcing strict permissions and ownership, ensuring that these critical files are not accessible
# or modifiable by unauthorized users.
#####################################

# Audit log files
readarray -t log_files < <(awk -F= '/^\s*log_file\s*/{print $2}' /etc/audit/auditd.conf)

for file in "${log_files[@]}"; do
    file="${file// /}"
    chmod g-w,o-rwx "$file"                   # log file directory mode is configured
    chmod u-x,g-wx,o-rwx "$(dirname "$file")" # log files mode is configured
    chown root:root "$(dirname "$file")"      # log files owner and group owner is configured
done

# Audit conf files
readarray -t conf_files < <(find /etc/audit/ -type f \( -name '*.conf' -o -name '*.rules' \))

for file in "${conf_files[@]}"; do
    chmod u-x,g-wx,o-rwx "$file" # configuration files mode is configured
    chown root:root "$file"      # configuration files owner and group is configured
done

# Audit tools files
tools_files=(
    "/sbin/auditctl"
    "/sbin/aureport"
    "/sbin/ausearch"
    "/sbin/autrace"
    "/sbin/auditd"
    "/sbin/augenrules"
)

for file in "${tools_files[@]}"; do
    if [[ -e "$file" ]]; then
        chmod go-w "$file"
        chown root:root "$file"
    fi
done
