#!/usr/bin/env bash

# Ensure bluetooth services are not in use
if rpm -q bluez &>/dev/null; then
    systemctl stop bluetooth.service &>/dev/null
    dnf remove -y bluez &>/dev/null
    echo "bluez package removed"
fi

# Check the IPv6 status
{
    l_output="" # Initialize the output variable

    # Check if IPv6 is not disabled in the kernel module parameters
    if ! grep -Pqs -- '^\h*0\b' /sys/module/ipv6/parameters/disable; then
        l_output="- IPv6 is not enabled"
    fi

    # Check if IPv6 is disabled via sysctl for all and default network interfaces
    if sysctl net.ipv6.conf.all.disable_ipv6 | grep -Pqs -- "^\h*net\.ipv6\.conf\.all\.disable_ipv6\h*=\h*1\b" &&
        sysctl net.ipv6.conf.default.disable_ipv6 | grep -Pqs -- "^\h*net\.ipv6\.conf\.default\.disable_ipv6\h*=\h*1\b"; then
        l_output="- IPv6 is not enabled"
    fi

    # If l_output is still empty, it means IPv6 is enabled
    [ -z "$l_output" ] && l_output="- IPv6 is enabled"

    # Print the result
    echo -e "\n$l_output\n"
}
