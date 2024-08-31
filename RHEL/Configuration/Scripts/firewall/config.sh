#!/usr/bin/env bash

##################################
# This script ensures that the system's firewall is configured securely using nftables,
# replacing any existing firewall services with nftables and applying a predefined ruleset.
##################################

output=()

# Ensure nftables is installed
if ! rpm -q nftables &>/dev/null; then
    dnf -y install nftables &>/dev/null
fi
output+=("$(rpm -q nftables)")

# Ensure there is not any other firewall service enabled
if rpm -q firewalld &>/dev/null; then
    systemctl disable firewalld.service &>/dev/null
    systemctl stop firewalld.service &>/dev/null
fi

# Configure the ruleset
cat 'rules.txt' >'/etc/nftables/nftables_rules.nft'
nft -f /etc/nftables/nftables_rules.nft
echo 'include "/etc/nftables/nftables_rules.nft"' >>/etc/sysconfig/nftables.conf

# Restart nftables
systemctl enable nftables.service &>/dev/null
systemctl restart nftables.service &>/dev/null


output+=("NFTables Rule Set:")
printf "%s\n" "${output[@]}"

# Print the running rules-set
nft list ruleset
