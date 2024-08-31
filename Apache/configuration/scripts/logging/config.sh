#!/usr/bin/env bash

config_file='/etc/httpd/conf.d/log.conf'

printf "%s\n" \
    'LogLevel notice core:info' \
    'ErrorLog "syslog:local1"' \
    'LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"" combined' \
    'CustomLog "|/usr/bin/logger -t httpd -p local2.*" combined' >"$config_file"

{
    echo 'local1.*						/var/log/httpd/error_log'
    echo 'local2.*						/var/log/httpd/access_log'
} >'/etc/rsyslog.d/httpd'

# Ensure Log Storage and Rotation Is Configured Correctly
cat 'logrotate_rules.txt' >/etc/logrotate.d/httpd

systemctl restart rsyslog.service
