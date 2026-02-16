#!/usr/bin/env bash

RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

get_serial_number() {
    local serialNumber
    serialNumber=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Serial Number" | head -n 1 | awk -F": " '{print $2}')
    
    [ -z "$serialNumber" ] && serialNumber=$(ioreg -l | grep IOPlatformSerialNumber | awk -F'"' '{print $4}')
    serialNumber=$(echo "$serialNumber" | xargs)
    
    [[ "$serialNumber" =~ ^[a-zA-Z0-9]{3,}$ ]] && echo "$serialNumber" || echo "N/A"
}

display_header() {
    local serial=$(get_serial_number)
    local inner_width=46
    
    center_line() {
        local text="$1"
        local text_len=${#text}
        local pad=$(( (inner_width - text_len) / 2 ))
        local rem=$(( (inner_width - text_len) % 2 ))
        printf '%*s%s%*s' "$pad" "" "$text" $((pad + rem)) ""
    }
    
    printf "${GRN}╭──────────────────────────────────────────────╮${NC}\n"
    printf "${GRN}│${NC}$(center_line "🔐 i-RealmPRO MDM MacBook")${GRN}│${NC}\n"
    printf "${GRN}│${NC}$(center_line "Serial: $serial")${GRN}│${NC}\n"
    printf "${GRN}│${NC}$(center_line "Professional MDM Removal Tool 🚀")${GRN}│${NC}\n"
    printf "${GRN}╰──────────────────────────────────────────────╯${NC}\n\n"
}

check_hardware() {
    printf "\n${BLU}🖥️  Hardware Information:${NC}\n"
    printf "----------------------------------------\n"
    printf "📦 Model         : %s\n" "$(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
    printf "🧩 Architecture  : %s\n" "$(uname -m)"
    printf "💻 macOS Version : %s\n" "$(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
    printf "🆔 UDID          : %s\n" "$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk '/IOPlatformUUID/ {print $3}' | tr -d \" || echo 'Unknown')"
    printf "----------------------------------------\n\n"
}

create_temp_user() {
    local dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
    
    [ ! -d "$dscl_path" ] && { printf "${RED}Error: Not in Recovery Mode. Path $dscl_path not found.${NC}\n"; return 1; }
    
    printf "👤 Username (default: Apple): "; read username
    printf "📝 Full name (default: Apple User): "; read fullname
    printf "🔑 Password (default: 1234): "; read -s password; echo
    
    username="${username:-Apple}"
    fullname="${fullname:-Apple User}"
    password="${password:-1234}"
    
    printf "${GRN}Creating user '$username'...${NC}\n"
    
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" || return 1
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$fullname"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
    mkdir -p "/Volumes/Data/Users/$username"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
    dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$password"
    dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"
    
    printf "${GRN}✓ User created${NC}\n"
}

block_mdm_servers() {
    local hosts_file="/Volumes/Macintosh HD/etc/hosts"
    
    [ ! -f "$hosts_file" ] && { printf "${RED}Error: $hosts_file not found${NC}\n"; return 1; }
    
    printf "${YEL}⛔ Blocking MDM servers...${NC}\n"
    
    cat >> "$hosts_file" <<EOF
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 iprofiles.apple.com
0.0.0.0 gdmf.apple.com
0.0.0.0 albert.apple.com
EOF
    
    printf "${GRN}✓ Servers blocked${NC}\n"
}

remove_mdm_profiles() {
    printf "${YEL}🧹 Removing MDM profiles...${NC}\n"
    
    rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfig"* 2>/dev/null
    touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
    touch "/Volumes/Data/private/var/db/.AppleSetupDone"
    
    printf "${GRN}✓ Profiles removed${NC}\n"
}

main() {
    clear
    display_header
    check_hardware
    
    printf "${CYAN}✨ Main Menu ✨${NC}\n"
    printf "----------------------------------------\n"
    printf "1. Bypass MDM Protection\n"
    printf "2. System Reboot\n"
    printf "3. Emergency Shell\n"
    printf "4. Exit\n"
    printf "----------------------------------------\n\n"
    
    while true; do
        printf "👉 Select (1-4): "
        read opt
        
        case $opt in
            1)
                printf "${YEL}🚀 Starting MDM bypass...${NC}\n"
                [ -d "/Volumes/Macintosh HD - Data" ] && diskutil rename "Macintosh HD - Data" "Data"
                create_temp_user && block_mdm_servers && remove_mdm_profiles && {
                    printf "${GRN}✅ Complete! Reboot now.${NC}\n"
                    break
                }
                ;;
            2)
                printf "${BLU}🔄 Rebooting...${NC}\n"
                reboot
                ;;
            3)
                printf "${YEL}🛠️ Launching shell...${NC}\n"
                /bin/zsh
                ;;
            4)
                printf "${GRN}👋 Exiting${NC}\n"
                exit 0
                ;;
            *)
                printf "${RED}Invalid option${NC}\n"
                ;;
        esac
    done
}

main
