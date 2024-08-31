#!/usr/bin/env bash

#######################################
# This script checks the client-side services.
# If a service it not useful for the system
# it is considered a good practice to disabe it
#  and remove its package
#######################################

output=()

insecure_services=(
    "ftp"
    "openldap-clients"
    "ypbind"
    "telnet"
    "tftp")

for pkg in "${insecure_services[@]}"; do
    if rpm -q "${pkg}" &>/dev/null; then
        dnf remove -y "$pkg" &>/dev/null
        output+=("Removed $pkg package")
    fi
done

[[ "${#output[@]}" -gt 0 ]] && printf "%s\n" "${output[@]}"
