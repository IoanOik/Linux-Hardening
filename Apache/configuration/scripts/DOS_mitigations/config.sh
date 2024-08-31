#!/usr/bin/env bash

declare -A parameters=(
    ["TimeOut"]='5'
    ["KeepAlive"]='On'
    ["MaxKeepAliveRequests"]='500'
    ["KeepAliveTimeout"]='15'
)

config_file='/etc/httpd/conf/httpd.conf'

declare -i flag=0

for pmtr in "${!parameters[@]}"; do
    if grep -q "^$pmtr" "$config_file"; then
        sed -i "/^$pmtr/c\\$pmtr ${parameters[$pmtr]}" "$config_file"
    else
        ((flag == 0)) && echo -e "\n# DOS mitigations" >>"$config_file"
        echo "$pmtr ${parameters[$pmtr]}" >>"$config_file"
        ((flag++))
    fi
done

# Ensure the Timeout Limits for Request Headers is Set to 40 or Less
# Ensure Timeout Limits for the Request Body is Set to 20 or Less
if ! grep -Fqi 'reqtimeout_module' < <(httpd -M); then
    echo 'LoadModule reqtimeout_module modules/mod_reqtimeout.so' >>/etc/httpd/conf.modules.d/00-base.conf
fi

echo 'RequestReadTimeout header=40,MinRate=500 body=20,MinRate=500' >>"$config_file"
