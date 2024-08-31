#!/usr/bin/env bash

#######################################
# This script checks the server-side services.
# If a service it not useful for the system
# it is considered a good practice to disabe it
#  and remove its package
#######################################

output=()

declare -A services_to_audit=(
    ["autofs"]='autofs'
    ["avahi"]='avahi-daemon'
    ["dhcp"]='dhcpd'
    ["bind"]='named.service'
    ["dnsmasq"]='dnsmasq'
    ["samba"]='smb'
    ["vsftpd"]='vsftpd'
    ["dovecot"]='dovecot'
    ["cyrus-imapd"]='cyrus-imapd'
    ["nfs-utils"]='nfs-server'
    ["ypserv"]='ypserv'
    ["cups"]='cups'
    ["rpcbind"]='rpcbind'
    ["rsync-daemon"]='rsyncd'
    ["net-snmp"]='snmpd'
    ["telnet-server"]='telnet'
    ["tftp-server"]='tftp'
    ["squid"]='squid'
    ["httpd"]='httpd'
    ["nginx"]='nginx'
    ["xinetd"]='xinetd'
)

for srvc in "${!services_to_audit[@]}"; do
    if rpm -q "${srvc}" &>/dev/null; then
        daemon="${services_to_audit[$srvc]}"
        systemctl stop "${daemon}".socket "${daemon}".service &>/dev/null
        dnf remove -y "${srvc}" &>/dev/null
        output+=("${srvc} service package removed")
    fi
done

# On servers only
if rpm -q 'xorg-x11-server-common' &>/dev/null; then
    dnf remove -y 'xorg-x11-server-common' &>/dev/null
    output+=("xorg-x11-server-common package removed")
fi

[[ "${#output[@]}" -gt 0 ]] && printf "%s\n" "${output[@]}"
