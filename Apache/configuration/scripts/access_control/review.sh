#!/usr/bin/env bash

# Ensure Access configurations inside the .conf apache files
# I think those checks are easier and safer, to be made manualy form the admin
echo "1) Verify the access for the root directory of the server's filesystem, is restricted by default"
echo "2) Verify the access for the DocumentRoot directory"
echo -e "3) Ensure OverRide Is Disabled for All Directories\n"
printf "%s\n" "Check the following files/directories" "/etc/httpd/conf/httpd.conf" "/etc/httpd/conf.d/"
