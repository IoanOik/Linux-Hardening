#!/usr/bin/env bash

############################
# This script ensures that the system's cryptographic policies are secure by applying specific settings
# that enhance overall security, particularly for SSH.
############################

# Ensure system wide crypto policy is not set in sshd configuration
if grep -Piq '^\h*CRYPTO_POLICY\h*=' /etc/sysconfig/sshd; then
    sed -ri "s/^\s*(CRYPTO_POLICY\s*=.*)$/# \1/" /etc/sysconfig/sshd
    systemctl reload sshd
fi

# Ensure system wide crypto policy disables sha1 hash and signature support
printf '%s\n' "# This is a subpolicy dropping the SHA1 hash and signature support" "hash = -SHA1" "sign = -*-SHA1" "sha1_in_certs = 0" >>/etc/crypto-policies/policies/modules/NO-SHA1.pmod
subpolicies='NO-SHA1:'

# Ensure system wide crypto policy disables macs less than 128 bits
if grep -Piq -- '^\h*mac\h*=\h*([^#\n\r]+)?-64\b' /etc/crypto-policies/state/CURRENT.pol; then
    printf '%s\n' "# This is a subpolicy to disable weak macs" "mac = -*-64" >>/etc/crypto-policies/policies/modules/NO-WEAKMAC.pmod
    subpolicies+='NO-WEAKMAC:'
fi

# Ensure system wide crypto policy disables cbc for ssh
printf '%s\n' "# This is a subpolicy to disable all CBC mode ciphers" "# for the SSH protocol (libssh and OpenSSH)" "cipher@SSH = -*-CBC" >>/etc/crypto-policies/policies/modules/NO-SSHCBC.pmod
subpolicies+='NO-SSHCBC:'

# Ensure system wide crypto policy disables chacha20-poly1305 for ssh
printf '%s\n' "# This is a subpolicy to disable the chacha20-poly1305 ciphers" "# for the SSH protocol (libssh and OpenSSH)" "cipher@SSH = -CHACHA20-POLY1305" >>/etc/crypto-policies/policies/modules/NO-SSHCHACHA20.pmod
subpolicies+='NO-SSHCHACHA20:'

# Ensure sshd MACs are configured
printf '%s\n' "# This is a subpolicy to disable weak MACs" "# for the SSH protocol (libssh and OpenSSH)" "mac@SSH = -HMAC-MD5* -UMAC-64* -UMAC-128*" >>/etc/crypto-policies/policies/modules/NO-SSHWEAKMACS.pmod
subpolicies+='NO-SSHWEAKMACS'

# Apply the new configuration
update-crypto-policies --set DEFAULT:"${subpolicies}"
