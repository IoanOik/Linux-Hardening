#!/usr/bin/env bash

config_file='/etc/httpd/conf/httpd.conf'

# Ensure the server's name is configured
if grep -Eq '^#ServerName' "$config_file"; then
    sed -i '/^#ServerName/c\ServerName localhost' "$config_file"
else
    echo 'ServerName localhost' >>"$config_file"
fi

systemctl restart httpd

declare -a output=()

declare -A modules=(
    ["log_config"]='1'
    ["dav_.*"]='0'
    ["status_module"]='0'
    ["proxy_[^m]"]='0'
    ["userdir_"]='0'
    ["info_module"]='0'
    ["auth_basic_module"]='0'
    ["auth_digest_module"]='0'
    ["autoindex_module"]='0'
)
# mod_proxy.so MUST be loaded

for mod in "${!modules[@]}"; do
    if [[ "${modules["$mod"]}" == '0' ]]; then
        if grep -qi "$mod" < <(httpd -M 2>/dev/null); then
            output+=("$mod")
            while read -r file; do
                sed -i "/$mod/s/^/## /" "$file"
                output+=("$file")
            done < <(grep -ril "$mod" '/etc/httpd/conf.modules.d')
        fi
    else
        if ! grep -qi "$mod" < <(httpd -M 2>/dev/null); then
            printf "%s\n" "LoadModule log_config_module modules/mod_log_config.so" >>'/etc/httpd/conf.modules.d/00-base.conf'
        fi
    fi
done

# Comment out autoindex configuration
if [[ -e '/etc/httpd/conf.d/autoindex.conf' ]]; then
    sed -i 's/^/# /' '/etc/httpd/conf.d/autoindex.conf'
fi

if [[ "${#output[@]}" -gt 0 ]]; then
    echo "Unloaded modules from those files:"
    printf "%s\n" "${output[@]}"
fi
