#!/usr/bin/env bash

#############################################
# This script performs an audit of specific kernel parameters.
# It checks both the running configuration and the persistent settings in the configuration files
# to ensure they match the expected values for the specified parameters
# If the corespondig parameter is wrongly set, the scriot also
# fixes both the running configuration and the files inside /etc/sysctl.d
#############################################

audit_pass_output="" audit_fail_output="" ipv6_disabled="" # Initialize output variables
kernel_param_list=("net.ipv4.ip_forward=0"
    "net.ipv6.conf.all.forwarding=0"
    "net.ipv4.conf.all.send_redirects=0"
    "net.ipv4.conf.default.send_redirects=0"
    "net.ipv4.icmp_ignore_bogus_error_responses=1"
    "net.ipv4.icmp_echo_ignore_broadcasts=1"
    "net.ipv4.conf.all.accept_redirects=0"
    "net.ipv4.conf.default.accept_redirects=0"
    "net.ipv6.conf.all.accept_redirects=0"
    "net.ipv6.conf.default.accept_redirects=0"
    "net.ipv4.conf.all.secure_redirects=0"
    "net.ipv4.conf.default.secure_redirects=0"
    "net.ipv4.conf.all.rp_filter=1"
    "net.ipv4.conf.default.rp_filter=1"
    "net.ipv4.conf.all.accept_source_route=0"
    "net.ipv4.conf.default.accept_source_route=0"
    "net.ipv6.conf.all.accept_source_route=0"
    "net.ipv6.conf.default.accept_source_route=0"
    "net.ipv4.conf.all.log_martians=1"
    "net.ipv4.conf.default.log_martians=1"
    "net.ipv4.tcp_syncookies=1"
    "net.ipv6.conf.all.accept_ra=0"
    "net.ipv6.conf.default.accept_ra=0"
)                                                                                                         # List of kernel parameters to check
ufw_sysctl_config="$([ -f /etc/default/ufw ] && awk -F= '/^\s*IPT_SYSCTL=/ {print $2}' /etc/default/ufw)" # UFW sysctl configuration file

# Function to check if IPv6 is disabled
check_ipv6_disabled() {
    ipv6_disabled=""
    ! grep -Pqs -- '^\h*0\b' /sys/module/ipv6/parameters/disable && ipv6_disabled="yes"
    if sysctl net.ipv6.conf.all.disable_ipv6 | grep -Pqs -- "^\h*net\.ipv6\.conf\.all\.disable_ipv6\h*=\h*1\b" &&
        sysctl net.ipv6.conf.default.disable_ipv6 | grep -Pqs -- "^\h*net\.ipv6\.conf\.default\.disable_ipv6\h*=\h*1\b"; then
        ipv6_disabled="yes"
    fi
    [ -z "$ipv6_disabled" ] && ipv6_disabled="no"
}

# Function to check and validate kernel parameters
check_kernel_parameter() {

    local fail
    declare -i fail='1'

    running_param_value="$(sysctl "$param_name" | awk -F= '{print $2}' | xargs)"
    if [ "$running_param_value" = "$expected_value" ]; then
        audit_pass_output="$audit_pass_output\n - \"$param_name\" is correctly set to \"$running_param_value\" in the running configuration"
    else
        audit_fail_output="$audit_fail_output\n - \"$param_name\" is incorrectly set to \"$running_param_value\" in the running configuration and should have a value of: \"$expected_value\""
        ((fail = 0))
    fi

    unset param_file_map
    declare -A param_file_map # Check durable setting (files)

    # Read configuration files and check if the parameter is set
    while read -r config_line; do
        if [ -n "$config_line" ]; then
            if [[ $config_line =~ ^\s*# ]]; then
                config_file="${config_line//# /}"
            else
                param_key="$(awk -F= '{print $1}' <<<"$config_line" | xargs)"
                [ "$param_key" = "$param_name" ] && param_file_map+=(["$param_key"]="$config_file")
            fi
        fi
    done < <(/usr/lib/systemd/systemd-sysctl --cat-config | grep -Po '^\h*([^#\n\r]+|#\h*\/[^#\n\r\h]+\.conf\b)')

    # Handle UFW-specific configurations
    if [ -n "$ufw_sysctl_config" ]; then
        param_key="$(grep -Po "^\h*$param_name\b" "$ufw_sysctl_config" | xargs)"
        param_key="${param_key//\//.}"
        [ "$param_key" = "$param_name" ] && param_file_map+=(["$param_key"]="$ufw_sysctl_config")
    fi

    # Validate the parameter values in configuration files
    if ((${#param_file_map[@]} > 0)); then
        while IFS="=" read -r config_param_name config_param_value; do
            config_param_name="${config_param_name// /}"
            config_param_value="${config_param_value// /}"
            if [ "$config_param_value" = "$expected_value" ]; then
                audit_pass_output="$audit_pass_output\n - \"$param_name\" is correctly set to \"$config_param_value\" in \"$(printf '%s' "${param_file_map[@]}")\"\n"
            else
                audit_fail_output="$audit_fail_output\n - \"$param_name\" is incorrectly set to \"$config_param_value\" in \"$(printf '%s' "${param_file_map[@]}")\" and should have a value of: \"$expected_value\"\n"
                ((fail = 0))
            fi
        done < <(grep -Po -- "^\h*$param_name\h*=\h*\H+" "${param_file_map[@]}")
    else
        audit_fail_output="$audit_fail_output\n - \"$param_name\" is not set in an included file\n** Note: \"$param_name\" May be set in a file that's ignored by the load procedure **\n"
        ((fail = 0))
    fi

    if ((fail == 0)); then
        printf '%s\n' "$param_name = $expected_value" >>/etc/sysctl.d/10-custom.conf
        sysctl -w "$param_name=$expected_value" &>/dev/null
    fi
}

# Main loop to assess and check parameters
while IFS="=" read -r param_name expected_value; do
    param_name="${param_name// /}"
    expected_value="${expected_value// /}"

    if grep -q '^net.ipv6.' <<<"$param_name"; then
        [ -z "$ipv6_disabled" ] && check_ipv6_disabled
        if [ "$ipv6_disabled" = "yes" ]; then
            audit_pass_output="$audit_pass_output\n - IPv6 is disabled on the system, \"$param_name\" is not applicable"
        else
            check_kernel_parameter
        fi
    else
        check_kernel_parameter
    fi
done < <(printf '%s\n' "${kernel_param_list[@]}")
sysctl -w net.ipv4.route.flush=1 &>/dev/null

# Provide output from checks
if [ -z "$audit_fail_output" ]; then
    echo -e "\n- Audit Result:\n ** PASS **\n$audit_pass_output\n"
else
    echo -e "\n- Audit Result:\n ** FAIL **\n - Reason(s) for audit failure:\n$audit_fail_output\n"
    [ -n "$audit_pass_output" ] && echo -e "\n- Correctly set:\n$audit_pass_output\n"
fi
