#!/usr/bin/env bash

# Ensure the proper Request Limits are configured

config_file='/etc/httpd/conf/httpd.conf'

declare -A parameters=(
    ["LimitRequestline"]='512'
    ["LimitRequestFields"]='100'
    ["LimitRequestFieldsize"]='1024'
    ["LimitRequestBody"]='102400'
)

declare -i flag=0

for pmtr in "${!parameters[@]}"; do
    if grep -q "^$pmtr" "$config_file"; then
        sed -i "/^$pmtr/c\\$pmtr ${parameters[$pmtr]}" "$config_file"
    else
        ((flag == 0)) && echo -e '\n# Request Limits parameters' >>"$config_file"
        echo "$pmtr ${parameters[$pmtr]}" >>"$config_file"
        ((flag++))
    fi
done
