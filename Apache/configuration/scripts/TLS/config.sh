#!/usr/bin/env bash

# Ensure mod_ssl and/or mod_nss is Installed
if ! grep -Eqi 'ssl_module|nss_module' < <(httpd -M); then
    dnf install -y mod_ssl >/dev/null
    systemctl restart httpd &>/dev/null
fi

config_file='/etc/httpd/conf.d/ssl.conf'

declare -A parameters=(
    ["SSLProtocol"]='TLSv1.3'
    ["SSLCipherSuite"]='EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH:!SHA1:!SHA256'
    ["SSLHonorCipherOrder"]='on'
    ["SSLInsecureRenegotiation"]='off'
    ["SSLCompression"]='off'
    ["SSLUseStapling"]='on'
    ["SSLStaplingCache"]='"shmcb:logs/ssl_staple_cache(512000)"'
)

declare -i flag=0

for pmtr in "${!parameters[@]}"; do
    if grep -q "^$pmtr" "$config_file"; then
        sed -i "/^$pmtr/c\\$pmtr ${parameters[$pmtr]}" "$config_file"
    else
        ((flag == 0)) && echo -e '\n# SSL specific parameters' >>'/etc/httpd/conf/httpd.conf'
        echo "$pmtr ${parameters[$pmtr]}" >>'/etc/httpd/conf/httpd.conf'
        ((flag++))
    fi
done

# Ensure ssl logging is not overriding log.conf
log_specific=("ErrorLog" "TransferLog" "LogLevel")

for option in "${log_specific[@]}"; do
    if grep -q "^$option" "$config_file"; then
        sed -i "/^$option/s/^/# /" "$config_file"
    fi
done

# Ensure HTTP Strict Transport Security Is Enabled
echo 'Header always set Strict-Transport-Security "max-age=600"' >>'/etc/httpd/conf/httpd.conf'
