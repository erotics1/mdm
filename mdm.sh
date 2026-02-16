#!/usr/bin/env bash
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

get_serial() {
    local sn=$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Serial Number/{print $2; exit}')
    [ -z "$sn" ] && sn=$(ioreg -l | awk -F'"' '/IOPlatformSerialNumber/{print $4; exit}')
    echo "${sn:-N/A}"
}

header() {
    clear
    printf "${GRN}╭──────────────────────────────────────────────╮${NC}\n"
    printf "${GRN}│          🔐 MDM Bypass Tool 🚀               │${NC}\n"
    printf "${GRN}│          Serial: %-27s│${NC}\n" "$(get_serial)"
    printf "${GRN}╰──────────────────────────────────────────────╯${NC}\n\n"
}

hardware_info() {
    printf "${BLU}🖥️  Hardware Info:${NC}\n"
    printf "Model: %s\n" "$(sysctl -n hw.model 2>/dev/null)"
    printf "macOS: %s\n" "$(sw_vers -productVersion 2>/dev/null)"
    printf "UDID: %s\n\n" "$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformUUID/{print $4}')"
}

create_user() {
    local path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
    [ ! -d "$path" ] && { printf "${RED}Not in Recovery Mode${NC}\n"; return 1; }
    
    read -p "Username [Apple]: " user
    read -p "Full name [Apple User]: " name
    read -sp "Password [1234]: " pass
    echo
    
    user=${user:-Apple}
    name=${name:-Apple User}
    pass=${pass:-1234}
    
    printf "${GRN}Creating user...${NC}\n"
    
    dscl -f "$path" localhost -create "/Local/Default/Users/$user"
    dscl -f "$path" localhost -create "/Local/Default/Users/$user" UserShell /bin/zsh
    dscl -f "$path" localhost -create "/Local/Default/Users/$user" RealName "$name"
    dscl -f "$path" localhost -create "/Local/Default/Users/$user" UniqueID 501
    dscl -f "$path" localhost -create "/Local/Default/Users/$user" PrimaryGroupID 20
    dscl -f "$path" localhost -create "/Local/Default/Users/$user" NFSHomeDirectory "/Users/$user"
    dscl -f "$path" localhost -passwd "/Local/Default/Users/$user" "$pass"
    dscl -f "$path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$user"
    mkdir -p "/Volumes/Data/Users/$user"
    
    printf "${GRN}✓ Done${NC}\n"
}

block_mdm() {
    local hosts='/Volumes/Macintosh HD/etc/hosts'
    [ ! -f "$hosts" ] && { printf "${RED}hosts file not found${NC}\n"; return 1; }
    
    printf "${YEL}Blocking MDM...${NC}\n"
    cat >> "$hosts" <<EOF
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 iprofiles.apple.com
0.0.0.0 gdmf.apple.com
0.0.0.0 albert.apple.com
EOF
    printf "${GRN}✓ Done${NC}\n"
}

remove_profiles() {
    printf "${YEL}Removing profiles...${NC}\n"
    rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfig"* 2>/dev/null
    touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
    touch "/Volumes/Data/private/var/db/.AppleSetupDone"
    printf "${GRN}✓ Done${NC}\n"
}

menu() {
    header
    hardware_info
    
    printf "${CYAN}Menu:${NC}\n"
    printf "1. Bypass MDM\n2. Reboot\n3. Shell\n4. Exit\n\n"
    
    while true; do
        read -p "Select (1-4): " opt
        case $opt in
            1)
                printf "${YEL}Starting bypass...${NC}\n"
                [ -d "/Volumes/Macintosh HD - Data" ] && diskutil rename "Macintosh HD - Data" Data
                create_user && block_mdm && remove_profiles && { printf "${GRN}✅ Complete! Reboot now.${NC}\n"; break; }
                ;;
            2) reboot;;
            3) /bin/zsh;;
            4) exit 0;;
            *) printf "${RED}Invalid${NC}\n";;
        esac
    done
}

menu
