#!/usr/bin/env bash

##################################
# This script is meant to check the state of certain kernel modules,
# and disable them if possible.
# For the loaded modules, the script will inform the admin,
# so he can review them and take further actions
#################################

fix_module() {
    local l_mod_name="$1"
    local error
    local a_showconfig=() # Create array with modprobe output
    already_fixed="y"     # Set to ignore duplicate checks

    while IFS= read -r l_showconfig; do
        a_showconfig+=("$l_showconfig")
    done < <(modprobe --showconfig | grep -P -- '\b(install|blacklist)\h+'"${l_mod_name//-/_}"'\b')

    info_output+=("--------------------")

    # Handle loaded modules
    if lsmod | grep "$l_mod_name" &>/dev/null; then
        if [[ "$2" == 'y' ]]; then
            # Unmounts everything related to this module
            if grep -iq "$l_mod_name" <(mount); then
                while IFS=' ' read -r -a module_mount; do
                    umount "${module_mount[2]}" &>/dev/null
                done < <(grep -i "$l_mod_name" <(mount))
            fi
            modprobe -r "$l_mod_name" 2>/dev/null
            ((error = $?))
            rmmod "$l_mod_name" 2>/dev/null
            info_output+=(" - unloading kernel module: \"${l_mod_name}\"")
            ((error != 0)) && info_output+=(" ERROR: Could not unload ${l_mod_name} module")
            ((error == 0)) && unloaded='y'
        else
            info_output+=(" - Kernel module: \"${l_mod_name}\" is loaded")
        fi
    else
        info_output+=(" - Kernel module: \"${l_mod_name}\" is not loaded")
    fi

    # Prevent manual installation
    if ! grep -Pq -- '\binstall\h+'"${l_mod_name//-/_}"'\h+\/bin\/(true|false)\b' <<<"${a_showconfig[*]}"; then
        printf '%s\n' "install $l_mod_name /bin/false" >>/etc/modprobe.d/"$l_mod_name".conf
        info_output+=(" - setting kernel module: \"$l_mod_name\" to \"/bin/false\"")
    fi

    # Add module to blacklist
    if ! grep -Pq -- '\bblacklist\h+'"${l_mod_name//-/_}"'\b' <<<"${a_showconfig[*]}"; then
        printf '%s\n' "blacklist $l_mod_name" >>/etc/modprobe.d/"$l_mod_name".conf
        info_output+=(" - denylisting kernel module: \"$l_mod_name\"")
    fi
}

unload=''
silent=''
already_fixed='n' # Also used in fix_module()
info_output=()    # Also used in fix_module()
unloaded=''

declare -a modules=("cramfs" "freevxfs" "hfs" "hfsplus" "jffs2" "squashfs" "udf" "usb-storage" "ceph" "gfs2" "cifs" "exfat" "fat" "fuse" "fscache" "nfs_common" "nfsd" "smbfs_common" "cachefiles" "dlm" "isofs" "lockd" "netfs" "nfs"
    "dccp"
    "tipc"
    "rds"
    "sctp"
)

while getopts ':uhs' opt; do
    case "$opt" in
    h)
        printf "%s\n\n" "This script is meant to check the state of certain kernel modules, and disable them if possible."
        printf "%s\n\n" "For the loaded modules, the script will inform the admin, so he can review them and take further actions"
        printf "%s\n" "Use the '-s' to execute in silent mode"
        printf "%s\n" "Use the '-u' to try and unload the loaded modules"
        exit 0
        ;;
    u)
        unload='y'
        ;;
    s)
        silent='y'
        ;;
    ?)
        echo "unknown option. Use option -h for more information"
        exit 1
        ;;
    esac
done

readarray -t mod_paths < <(readlink -f /lib/modules/**/kernel/{fs,drivers,net} | sort -u)

for mod in "${modules[@]}"; do
    for base_directory in "${mod_paths[@]}"; do
        if [[ -d "$base_directory/${mod/-/\/}" ]] && [[ -n "$(ls -A "$base_directory"/"${mod/-/\/}")" ]]; then
            [[ "$mod" =~ overlay ]] && mod="${mod::-2}"
            [[ "${already_fixed}" != "y" ]] && fix_module "$mod" "$unload"
        fi
    done
    already_fixed='n'
done

# Regenerate the default initramfs image for the currently running kernel
[[ "$unload" == 'y' && "$unloaded" == 'y' ]] && dracut -f

if [[ "${#info_output[@]}" -gt 0 ]] && [[ "$silent" != 'y' ]]; then
    printf "%s\n" "${info_output[@]}"
fi
