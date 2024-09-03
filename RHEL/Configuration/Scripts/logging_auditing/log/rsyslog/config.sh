#!/usr/bin/env bash

#######################
# Rsyslog configuration script
#######################

# Ensure rsyslog is installed, enalbed and active
if ! rpm -q rsyslog &>/dev/null; then
    dnf install -y rsyslog &>/dev/null
fi

rpm -q rsyslog

# Create a custom file for rsysyslog configuration changes, propably is already there
#printf "\n%s" '# Include additional configuration files' 'include(file="/etc/rsyslog.d/*.conf")' >>'/etc/rsyslog.conf'

# Ensure rsyslog log file creation mode is configured
# shellcheck disable=SC2016
{
    printf "%s\n" '$FileCreateMode 0640'

    # Ensure rsyslog is configured to send logs to a remote log server
    printf "%s\n" '*.info action(type="omfwd" target="1.1.1.1" port="514" protocol="udp" action.resumeRetryCount="100" queue.type="LinkedList" queue.size="1000")'

    # Ensure rsyslog listens on dev/log domain socket for any log  messages
    # from journald or auditd
    printf "%s\n" 'module(load="imuxsock" SysSock.Use="on" SysSock.UsePIDFromSystem="on")'

} >'/etc/rsyslog.d/custom.conf'
# Ensure rsyslog logrotate is configured
cat "rules.txt" >'/etc/logrotate.d/rsyslog'

# Restart rsyslog service
systemctl unmask rsyslog.service &>/dev/null
systemctl enable rsyslog.service &>/dev/null
systemctl start rsyslog.service &>/dev/null
