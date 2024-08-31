#!/usr/bin/env bash

#################
# This script checks for the GPG keys URLs existance on the system,
# the 'gpgcheck' and 'repo_gpgcheck' options.
##################

# Ensure GPG URLs existance
readarray -t repos < <(find /etc/yum.repos.d/ -type f -name '*.repo')
declare -i keys=0
declare -a keyless_repos=()

for repo in "${repos[@]}"; do
    if grep -q 'gpgkey' "$repo"; then
        ((keys++))
    else
        keyless_repos+=("$repo")
    fi
done

if [[ $keys -ge "${#repos[@]}" ]]; then
    echo "Found at least one URL key per repository"
else
    echo "URLs are short, these repos do not include key(s) "
    printf "%s\n" "${keyless_repos[@]}"
fi

# gpgcheck option
if ! grep -Piq -- '^\h*gpgcheck\h*=\h*(1|true|yes)\b' /etc/dnf/dnf.conf; then
    sed -i 's/^gpgcheck\s*=\s*.*/gpgcheck=1/' /etc/dnf/dnf.conf
fi

readarray -t failed_repos < <(grep -Prisl -- '^\h*gpgcheck\h*=\h*(0|[2-9]|[1-9][0-9]+|false|no)\b' /etc/yum.repos.d/)

if [[ "${#failed_repos[@]}" -gt 0 ]]; then
    for file in "${failed_repos[@]}"; do
        sed -i "s/^gpgcheck\s*=\s*.*/gpgcheck=1/" "$file"
    done
fi

# repo_gpgcheck

if ! grep -Pq '^repo_gpgcheck=1' /etc/dnf/dnf.conf; then
    echo "repo_gpgcheck=1" >>/etc/dnf/dnf.conf
fi

echo -e "Check the following files and make sure every repo that does\n not support 'repo_gpgcheck' option, has it set to 0"
ls -l /etc/yum.repos.d/

echo -e "\nYour repolist:\n"
dnf repolist
