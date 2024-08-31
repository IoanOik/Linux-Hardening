#!/usr/bin/env bash

#######################################
# This script checks various kernel parameters and core dump settings,
# to ensure they are set correctly according to predefined values.
# It attempts to remediate any incorrect settings found.
#######################################

# Initialize output variables
audit_pass_output="" audit_fail_output=""

# List of kernel parameters to check
a_parlist=("kernel.randomize_va_space=2" "kernel.yama.ptrace_scope=1" "ProcessSizeMax=0" "Storage=none")

# Get the IPT_SYSCTL value from UFW configuration if it exists
l_ufwscf="$([ -f /etc/default/ufw ] && awk -F= '/^\s*IPT_SYSCTL=/ {print $2}' /etc/default/ufw)"

# Function to check and remediate kernel parameters
kernel_parameter_chk() {

    local fail
    declare -i fail='1'

    # Get the current value of the kernel parameter
    l_krp="$(sysctl "$parameter_name" | awk -F= '{print $2}' | xargs)"
    if [ "$l_krp" = "$parameter_value" ]; then
        audit_pass_output="$audit_pass_output\n - \"$parameter_name\" is correctly set to \"$l_krp\" in the running configuration"
    else
        audit_fail_output="$audit_fail_output\n - \"$parameter_name\" is incorrectly set to \"$l_krp\" in the running configuration and should have a value of: \"$parameter_value\""
        ((fail = 0))
    fi

    # Check the durable setting (files)
    unset A_out
    declare -A A_out

    # Read the configuration files and identify where the parameter is set
    while read -r l_out; do
        if [ -n "$l_out" ]; then
            if [[ $l_out =~ ^\s*# ]]; then
                l_file="${l_out//# /}"
            else
                l_kpar="$(awk -F= '{print $1}' <<<"$l_out" | xargs)"
                [ "$l_kpar" = "$parameter_name" ] && A_out+=(["$l_kpar"]="$l_file")
            fi
        fi
    done < <(/usr/lib/systemd/systemd-sysctl --cat-config | grep -Po '^\h*([^#\n\r]+|#\h*\/[^#\n\r\h]+\.conf\b)')

    # Account for systems with UFW (Not covered by systemd-sysctl --cat-config)
    if [ -n "$l_ufwscf" ]; then
        l_kpar="$(grep -Po "^\h*$parameter_name\b" "$l_ufwscf" | xargs)"
        l_kpar="${l_kpar//\//.}"
        [ "$l_kpar" = "$parameter_name" ] && A_out+=(["$l_kpar"]="$l_ufwscf")
    fi

    # Assess output from files and generate output
    if ((${#A_out[@]} > 0)); then
        while IFS="=" read -r l_fkpname l_fkpvalue; do
            l_fkpname="${l_fkpname// /}"
            l_fkpvalue="${l_fkpvalue// /}"
            if [ "$l_fkpvalue" = "$parameter_value" ]; then
                audit_pass_output="$audit_pass_output\n - \"$parameter_name\" is correctly set to \"$l_krp\" in \"$(printf '%s' "${A_out[@]}")\"\n"
            else
                audit_fail_output="$audit_fail_output\n - \"$parameter_name\" is incorrectly set to \"$l_fkpvalue\" in \"$(printf '%s' "${A_out[@]}")\" and should have a value of: \"$parameter_value\"\n"
                ((fail = 0))
            fi
        done < <(grep -Po -- "^\h*$parameter_name\h*=\h*\H+" "${A_out[@]}")
    else
        audit_fail_output="$audit_fail_output\n - \"$parameter_name\" is not set in an included file\n ** Note: \"$parameter_name\" May be set in a file that's ignored by load procedure **\n"
        ((fail = 0))
    fi

    # Remediate the setting if it was incorrect
    if ((fail == 0)); then
        sysctl -w "${parameter_name}=${parameter_value}"
        printf "%s = %s\n" "${parameter_name}" "${parameter_value}" >>/etc/sysctl.d/60-kernel_sysctl.conf

    fi
}

# Function to check and remediate core dump parameters
coredump_parameter_chk() {

    local fail
    declare -i fail='1'

    # Clear any previous values and declare a new associative array to store file check results
    unset file_check_output
    declare -A file_check_output

    # Read the configuration file(s) and check for the parameter
    while read -r config_line; do
        if [ -n "$config_line" ]; then
            if [[ $config_line =~ ^\s*# ]]; then
                config_file="${config_line//# /}"
            else
                systemd_parameter="$(awk -F= '{print $1}' <<<"$config_line" | xargs)"
                grep -Piq -- "^\h*$parameter_name\b" <<<"$systemd_parameter" && file_check_output+=(["$systemd_parameter"]="$config_file")
            fi
        fi
    done < <(/usr/bin/systemd-analyze cat-config "/etc/systemd/coredump.conf" | grep -Pio '^\h*([^#\n\r]+|#\h*\/[^#\n\r\h]+\.conf\b)')

    # Assess output from files and generate results
    if ((${#file_check_output[@]} > 0)); then
        while IFS="=" read -r config_file_param_name config_file_param_value; do
            config_file_param_name="${config_file_param_name// /}"
            config_file_param_value="${config_file_param_value// /}"
            if grep -Piq "^\h*$parameter_value\b" <<<"$config_file_param_value"; then
                audit_pass_output="$audit_pass_output\n - \"$parameter_name\" is correctly set to \"$config_file_param_value\" in \"$(printf '%s' "${file_check_output[@]}")\"\n"
            else
                audit_fail_output="$audit_fail_output\n - \"$parameter_name\" is incorrectly set to \"$config_file_param_value\" in \"$(printf '%s' "${file_check_output[@]}")\" and should have a value matching: \"$parameter_value\"\n"
                ((fail = 0))
            fi
        done < <(grep -Pio -- "^\h*$parameter_name\h*=\h*\H+" "${file_check_output[@]}")
    else
        audit_fail_output="$audit_fail_output\n - \"$parameter_name\" is not set in an included file\n ** Note: \"$parameter_name\" May be set in a file that's ignored by load procedure **\n"
        ((fail = 0))
    fi

    # Remediate the setting if it was incorrect
    if ((fail == 0)); then
        [[ ! -d /etc/systemd/coredump.conf.d/ ]] && mkdir /etc/systemd/coredump.conf.d/
        if grep -Psq -- '^\h*\[Coredump\]' /etc/systemd/coredump.conf.d/60-coredump.conf; then
            printf '%s\n' "${parameter_name}=${parameter_value}" >>/etc/systemd/coredump.conf.d/60-coredump.conf
        else
            printf '%s\n' "[Coredump]" "${parameter_name}=${parameter_value}" >>/etc/systemd/coredump.conf.d/60-coredump.conf
        fi
    fi

}

# Assess and check parameters
while IFS="=" read -r parameter_name parameter_value; do
    parameter_name="${parameter_name// /}"
    parameter_value="${parameter_value// /}"
    # Skip check if IPv6 is disabled and the parameter is related to IPv6
    if ! grep -Pqs '^\h*0\b' /sys/module/ipv6/parameters/disable && grep -q '^net.ipv6.' <<<"$parameter_name"; then
        audit_pass_output="$audit_pass_output\n - IPv6 is disabled on the system, \"$parameter_name\" is not applicable"
    else
        if [[ "${parameter_name}" == "ProcessSizeMax" || "${parameter_name}" == "Storage" ]]; then
            coredump_parameter_chk
        else
            kernel_parameter_chk
        fi
    fi
done < <(printf '%s\n' "${a_parlist[@]}")

# Provide output from checks
if [ -z "$audit_fail_output" ]; then
    echo -e "\n- Audit Result:\n ** PASS **\n$audit_pass_output\n"
else
    echo -e "\n- Audit Result:\n ** FAIL **\n - Reason(s) for audit failure:\n$audit_fail_output\n"
    [ -n "$audit_pass_output" ] && echo -e "\n- Correctly set:\n$audit_pass_output\n"
fi
