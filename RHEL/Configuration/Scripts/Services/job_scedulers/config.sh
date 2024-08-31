#!/usr/bin/env bash

######################################
# This script configures cron and at jobs on the system.
# It ensures that:
# - The cron daemon is enabled and active.
# - Critical cron configuration files have the correct ownership and permissions.
# - Cron job access is restricted to authorized users.
# - The `at` command configuration is correctly set up.
######################################

# Cron jobs

if rpm -q 'cronie' &>/dev/null; then
    # Ensure cron daemon is enabled and active
    if ! systemctl is-enabled crond.service &>/dev/null; then
        systemctl enable crond.service &>/dev/null
    fi

    if ! systemctl is-active &>/dev/null; then
        systemctl start &>/dev/null
    fi

    # Ensure permissions on critical files are configured
    files=("/etc/crontab"
        "/etc/cron.hourly"
        "/etc/cron.daily"
        "etc/cron.weekly"
        "/etc/cron.monthly"
        "etc/cron.d")

    for file in "${files[@]}"; do
        chown root:root "$file" &>/dev/null
        chmod og-rwx "$file" &>/dev/null
    done

    # Ensure crontab is restricted to authorized users
    [ ! -e "/etc/cron.allow" ] && touch /etc/cron.allow
    chown root:root /etc/cron.allow
    chmod u-x,g-wx,o-rwx /etc/cron.allow

    # [ -e "/etc/cron.deny" ] && chown root:root /etc/cron.deny
    # [ -e "/etc/cron.deny" ] && chmod u-x,g-wx,o-rwx /etc/cron.deny
    [ -e "/etc/cron.deny" ] && rm -f "/etc/cron.deny"
fi

# at jobs

if rpm -q 'at' &>/dev/null; then
    grep -Pq -- '^daemon\b' /etc/group && l_group="daemon" || l_group="root"
    [ ! -e "/etc/at.allow" ] && touch /etc/at.allow
    chown root:"$l_group" /etc/at.allow
    chmod u-x,g-wx,o-rwx /etc/at.allow
    # [ -e "/etc/at.deny" ] && chown root:"$l_group" /etc/at.deny
    # [ -e "/etc/at.deny" ] && chmod u-x,g-wx,o-rwx /etc/at.deny
    [ -e "/etc/at.deny" ] && rm -f "/etc/at.deny"
fi
