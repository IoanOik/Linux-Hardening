#!/usr/bin/env bash

config_file='/etc/httpd/conf/httpd.conf'

# Ensure ServerTokens is Set to 'Prod' or 'ProductOnly'
if grep -q '^ServerTokens' "$config_file"; then
    sed -i '/^ServerTokens/c\ServerTokens ProductOnly' "$config_file"
else
    echo -e "\n# Ensure ServerToken does not give system information" >>"$config_file"
    echo 'ServerTokens ProductOnly' >>"$config_file"
fi

# Ensure ServerSignature Is Not Enabled
if grep -q '^ServerSignature' "$config_file"; then
    sed -i '/^ServerSignature/c\ServerSignature Off' "$config_file"
else
    echo -e "\n# Ensure ServerSignature does not give system information" >>"$config_file"
    echo 'ServerSignature Off' >>"$config_file"
fi

# Ensure ETag Response Header Fields Do Not Include Inodes
if grep -q '^FileETag' "$config_file"; then
    sed -i '/^FileETag/s/^/# ' "$config_file"
fi
