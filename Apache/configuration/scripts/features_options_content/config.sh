#!/usr/bin/env bash

# Options Directive

echo "1) Ensure Options for the OS Root Directory Are Restricted: Options None"
echo "2) Ensure Options for the Web Root Directory Are Restricted: Options None"
echo -e "3) Ensure Options for Other Directories Are Minimized\n"

config_file='/etc/httpd/conf/httpd.conf'

# Ensure Default HTML Content Is Removed
sed -i '/^.*/s/^/# /' /etc/httpd/conf.d/welcome.conf
dnf remove -y httpd-manual &>/dev/null

if grep -qi '^<Location' "$config_file"; then
    echo 'Ensure every Loction directive is commented out'
fi

# Ensure the Default CGI Content printenv Script Is Removed
rm -f /var/www/cgi-bin/printenv &>/dev/null

# Ensure the Default CGI Content test-cgi Script Is Removed
rm -f /var/www/cgi-bin/test-cgi &>/dev/null

# Ensure HTTP Request Methods Are Restricted
echo 'Ensure the only allowed methods inside the Document Root Directory are: GET POST OPTIONS'

# Ensure the HTTP TRACE Method Is Disabled
if grep -i '^TraceEnable' "$config_file"; then
    sed -i '/^TraceEnable/c\TraceEnable off' "$config_file"
else
    printf "%s\n" '# Ensure the HTTP TRACE Method Is Disabled' \
        'TraceEnable off' >>"$config_file"
fi

# Ensure request re-writing is enabled
if grep -i '^RewriteEngine' "$config_file"; then
    sed -i '/^RewriteEngine/c\RewriteEngine On' "$config_file"
else
    printf "%s\n" '# Ensure request re-writing is enabled' \
        'RewriteEngine On' >>"$config_file"
fi

{
    # Ensure Old HTTP Protocol Versions Are Disallowed and
    # the server redirects every accepted HTTP traffic to HTTPS
    printf "%s\n" \
        '' \
        '# Ensure only HTTP 1.1 and above is used' \
        'RewriteCond %{THE_REQUEST} !HTTP/(1\.1|2|3)$' \
        'RewriteRule .* - [L,F]' \
        '# Redirect all HTTP traffic to HTTPS' \
        'RewriteCond %{HTTPS} !=on' \
        'RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [R=301]'

    # Ensure IP Address Based Requests Are Disallowed
    printf "%s\n" \
        '' \
        '# Ensure IP Address Based Requests Are Disallowed' \
        'RewriteCond %{HTTP_HOST} !^www\.example\.com [NC]' \
        'RewriteCond %{REQUEST_URI} !^/error [NC]' \
        'RewriteRule ^(.*) - [L,F]'

    # Ensure Access to .git Files Is Restricted
    printf "%s\n" \
        '' \
        '# Ensure Access to .git Files Is Restricted' \
        '<DirectoryMatch /\.git>' \
        '   Require all denied' \
        '</DirectoryMatch>'

    # Ensure Access to .svn Files Is Restricted
    printf "%s\n" \
        '' \
        '# Ensure Access to .svn Files Is Restricted' \
        '<DirectoryMatch /\.svn>' \
        '   Require all denied' \
        '</DirectoryMatch>'
} >>"$config_file"

# Ensure Access to .ht* Files Is Restricted
# It is commented out because it exists in the default configuration

# printf "%s\n" \
#     '<FilesMatch ^\.ht>' \
#     '   Require all denied' \
#     '</FilesMatch>' >>"$config_file"

# Ensure the IP Addresses for Listening for Requests Are Specified
if grep -qi '^Listen' "$config_file"; then
    echo 'Verify you have an explicit IP address in the Listen directive'
fi

{
    # Ensure Browser Framing Is Restricted
    # echo Header always append Content-Security-Policy "frame-ancestors 'self'"

    # Ensure HTTP Header Referrer-Policy is set appropriately
    echo 'Header set Referrer-Policy "strict-origin-when-cross-origin"'

    #Ensure HTTP Header Permissions-Policy is set appropriately
    echo 'Header set Permissions-Policy "geolocation=(self), camera=(), microphone=()"'

} >>"$config_file"
