#!/usr/bin/env bash

####################
# This script ensures certain sshd options
# are correctly set.
####################

output=()

declare -A parameters=(
    ["Banner"]='/etc/issue.net'
    ["ClientAliveInterval"]='15'
    ["ClientAliveCountMax"]='3'
    ["DisableForwarding"]='yes'
    ["GSSAPIAuthentication"]='no'
    ["HostbasedAuthentication"]='no'
    ["IgnoreRhosts"]='yes'
    ["LoginGraceTime"]='60'
    ["LogLevel"]='INFO'
    ["MaxAuthTries"]='3'
    ["MaxStartups"]='10:30:60'
    ["MaxSessions"]='10'
    ["PermitEmptyPasswords"]='no'
    ["PermitRootLogin"]='no'
    ["PermitUserEnvironment"]='no'
    ["UsePAM"]='yes'
)

for par_name in "${!parameters[@]}"; do
    current_value="$(sshd -T | grep -i "$par_name" | awk '{print $2}')"
    if [[ "${parameters[$par_name]}" != "${current_value// /}" ]]; then
        sed -i "1i ${par_name} ${parameters[$par_name]}" '/etc/ssh/sshd_config.d/50-redhat.conf'
        output+=("Parameter $par_name setted to ${parameters[$par_name]}")
    fi
done

[[ "${#output[@]}" -gt 0 ]] && printf "%s\n" "${output[@]}"
