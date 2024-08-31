#!/usr/bin/env bash

# Apache variables
server_root="$(grep -E '^ServerRoot' /etc/httpd/conf/httpd.conf | cut -d' ' -f2)"
server_root="${server_root//\"/}"
document_root="$(grep -E '^DocumentRoot' "${server_root}"/conf/httpd.conf | cut -d' ' -f2)"
document_root="${document_root//\"/}"

# Ensure the Apache Web Server Runs as a Non-Root User
if grep -Fqi 'apache' '/etc/passwd'; then
    awk -F: ' BEGIN { code = 0 }
        {
            if($3 > 999) {
                print "UID is greater than 999, posible user account"
                code = 1
            }

            if($4 > 999) {
                print "GID is greater than 999, posible user account"
                code = 1
            }

            if($7 != "/sbin/nologin" && $7 != "/dev/null") {
                print "Login shell is not properly configured"
                code = 1
            }
        }
        END {
            if(code == 1) {
                print "You need to check/reconfigure the apache account!"
                exit 1
            }
        }
    ' < <(grep -Fi 'apache' '/etc/passwd')
else
    useradd apache -r -g apache -d /usr/share/httpd -s /sbin/nologin
fi

if (($? == 1)); then
    echo "Re-run the script after fixing the account"
    exit 1
fi

sed -i '/^User/c\User apache' "${server_root}/conf/httpd.conf"
sed -i '/^Group/c\Group apache' "${server_root}/conf/httpd.conf"

# Ensure the account is password-locked
passwd -l apache >/dev/null

if systemctl is-active httpd &>/dev/null; then
    echo -e "httpd processes on the system:\n"
    ps -f $(pgrep -f httpd)
fi

# Ensure Apache Directories and Files Are Owned By Root
chown -R root "${server_root}/"

# Ensure Other Write Access on Apache Directories and Files is Restricted
chmod -R o-w "${server_root}/"

# Ensure the Core Dump Directory Is Secured
# There is not Core Dump Directory specified by default in httpd configuration
if grep -iq '^CoreDumpDirectory' "${server_root}"/conf/httpd.conf; then
    echo "Check the CoreDumpDirectory directive inside the httpd.conf"
fi

# Ensure the Lock File Is Secured
if grep -iq '^Mutex' "${server_root}"/conf/httpd.conf; then
    echo "Check the Mutex directive inside the httpd.conf"
fi

# Ensure the Pid File Is Secured
# By default this file is in /run/httpd/ directory
chown root:apache "${server_root}/run"

# Ensure the ScoreBoard File Is Secured
# By default this file is created entirely in memory (using anonymous shared memory)
if grep -iq '^ScoreBoardFile' "${server_root}"/conf/httpd.conf; then
    echo "Check the ScoreBoardFile directive inside the httpd.conf"
fi

# Ensure Group Write Access for the Apache Directories and
# Files Is Properly Restricted
find -L "${server_root}/" ! -type l -perm /g=w -exec chmod g-w {} +

# Ensure Group Write Access for the Document Root
# Directories and Files Is Properly Restricted
find -L "${document_root}/" -group apache -perm /g=w -exec chmod g-w {} +
