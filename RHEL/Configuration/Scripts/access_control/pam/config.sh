#!/usr/bin/env bash

##############################
# This script ensures the proper
# configuration for some PAM config files
##############################

# Ensure latest version of pam is installed
if ! rpm -q pam &>/dev/null; then
    dnf -y install pam &>/dev/null && dnf -y upgrade pam &>/dev/null
fi

# Ensure latest version of libpwquality is installed
if ! rpm -q libpwquality &>/dev/null; then
    dnf -y install libpwquality &>/dev/null && dnf -y upgrade libpwquality &>/dev/null
fi

# Configure options in faillock.conf, pwquality.conf and pwhistory.conf files

declare -A faillock_parameters=(
    ["deny"]=' = 5'
    ["unlock_time"]=' = 900'
    ["even_deny-root"]=''
    ["root_unlock_time"]=' = 60'
)

for param_name in "${!faillock_parameters[@]}"; do
    echo "${param_name}${faillock_parameters[$param_name]}" >>/etc/security/faillock.conf
done

declare -A pwquality_parameters=(
    ["difok"]=' = 2'
    ["minlen"]=' = 14'
    ["minclass"]=' = 4'
    ["maxrepeat"]=' = 2'
    ["maxsequence"]=' = 3'
    ["dictcheck"]=' = 1'
    ["enforce_for_root"]=''
)

for param_name in "${!pwquality_parameters[@]}"; do
    echo "${param_name}${pwquality_parameters[$param_name]}" >>/etc/security/pwquality.conf
done

declare -A pwhistory_parameters=(
    ["remember"]=' = 24'
    ["enforce_for_root"]=''
)

for param_name in "${!pwhistory_parameters[@]}"; do
    echo "${param_name}${pwhistory_parameters[$param_name]}" >>/etc/security/pwhistory.conf
done
