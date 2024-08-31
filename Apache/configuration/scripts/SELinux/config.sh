#!/usr/bin/env bash

# Ensure SELinux Is Enabled in Enforcing Mode
if grep -q '^SELINUX' '/etc/selinux/config'; then
    sed -i '/^SELINUX/c\SELINUX=enforcing' '/etc/selinux/config'
else
    echo 'SELINUX=enforcing' >>'/etc/selinux/config'
fi
setenforce 1
systemctl restart httpd

# Ensure Apache Processes Run in the httpd_t Confined
# Context
while IFS= read -r -a process; do
    if ! grep -Fq 'httpd_t' <<<"${process[0]}"; then
        echo -e "Process with PID ${process[1]} is not confined to the \'httpd_t\' SELinux context"
    fi
done < <(ps -Z --no-headers $(pgrep -f httpd))

# Ensure the httpd_t Type is Not in Permissive Mode
httpd_module="$(grep -F 'apache' < <(semanage permissive -l))"

if [[ -n "$httpd_module" ]]; then
    semanage permissive -d "$httpd_module"
fi

# Ensure Only the Necessary SELinux Booleans are Enabled
echo 'The following booleans are enabled for the Apache web server:'
grep -Ev '(off[[:blank:]]*,[[:blank:]]*off)' < <(semanage boolean -l | grep httpd)

echo "It is a good idea to review them and disable the ones that are not a necessity"
