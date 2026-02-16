#!/usr/bin/env bash

RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

get_serial_number() {
    local serialNumber
    serialNumber=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Serial Number" | head -n 1 | awk -F": " '{print $2}')
    
    if [ -z "$serialNumber" ]; then
        serialNumber=$(ioreg -l | grep IOPlatformSerialNumber | awk -F'"' '{print $4}')
    fi
    
    serialNumber=$(echo "$serialNumber" | xargs)
    
    if [[ "$serialNumber" =~ ^[a-zA-Z0-9]{3,}$ ]]; then
        echo "$serialNumber"
    else
        echo "N/A"
    fi
}

display_header() {
    local serial
    serial=$(get_serial_number)
    
    local inner_width=46
    local title="🔐 i-RealmPRO MDM MacBook"
    local serial_line="Serial: $serial"
    local tool="Professional MDM Removal Tool 🚀"
    
    center_line() {
        local text="$1"
        local text_len=${#text}
        local pad=$(( (inner_width - text_len) / 2 ))
        local rem=$(( (inner_width - text_len) % 2 ))
        printf '%*s%s%*s' "$pad" "" "$text" $((pad + rem)) ""
    }
    
    printf "${GRN}╭──────────────────────────────────────────────╮${NC}\n"
    printf "${GRN}│${NC}$(center_line "$title")${GRN}│${NC}\n"
    printf "${GRN}│${NC}$(center_line "$serial_line")${GRN}│${NC}\n"
    printf "${GRN}│${NC}$(center_line "$tool")${GRN}│${NC}\n"
    printf "${GRN}╰──────────────────────────────────────────────╯${NC}\n\n"
}

check_hardware() {
    echo ""
    printf "${BLU}🖥️  Hardware Information:${NC}\n"
    printf "%s\n" "----------------------------------------"
    printf "📦 Model          : %s\n" "$(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
    printf "🧩 Architecture   : %s\n" "$(uname -m)"
    printf "💻 macOS Version  : %s\n" "$(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
    printf "🆔 UDID           : %s\n" "$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk '/IOPlatformUUID/ {print $3}' | tr -d \" || echo 'Unknown')"
    printf "%s\n" "----------------------------------------"
    echo ""
    printf "${CYAN}Note:${NC} Hardware details retrieved from system configuration.\n"
    echo ""
}

create_temp_user() {
    local dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
    
    if [ ! -d "$dscl_path" ]; then
        printf "${RED}Error: Path $dscl_path not found. Ensure booted from Recovery.${NC}\n"
        return 1
    fi
    
    read -p "👤 Enter temporary username (default: Apple): " username
    read -p "📝 Enter full name (default: Apple User): " fullname
    read -s -p "🔑 Enter password (default: 1234): " password
    echo
    
    username="${username:-Apple}"
    fullname="${fullname:-Apple User}"
    password="${password:-1234}"
    
    printf "${GRN}Creating temporary user account...${NC}\n"
    
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$fullname"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
    mkdir -p "/Volumes/Data/Users/$username"
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
    dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$password"
    dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username"
    
    printf "${GRN}✓ User '$username' created successfully.${NC}\n"
}

block_mdm_servers() {
    local hosts_file="/Volumes/Macintosh HD/etc/hosts"
    
    if [ ! -f "$hosts_file" ]; then
        printf "${RED}Error: $hosts_file not found.${NC}\n"
        return 1
    fi
    
    printf "${YEL}⛔ Blocking MDM servers...${NC}\n"
    
    {
        echo "0.0.0.0 deviceenrollment.apple.com"
        echo "0.0.0.0 mdmenrollment.apple.com"
        echo "0.0.0.0 iprofiles.apple.com"
        echo "0.0.0.0 gdmf.apple.com"
        echo "0.0.0.0 albert.apple.com"
    } >> "$hosts_file"
    
    printf "${GRN}✓ MDM servers blocked.${NC}\n"
}

remove_mdm_profiles() {
    printf "${YEL}🧹 Removing MDM profiles...${NC}\n"
    
    rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfig"* 2>/dev/null
    touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
    touch "/Volumes/Data/private/var/db/.AppleSetupDone"
    
    printf "${GRN}✓ MDM profiles removed.${NC}\n"
}

main() {
    clear
    display_header
    
    local serial
    serial=$(get_serial_number)
    
    check_hardware
    
    printf "${CYAN}✨ Main Menu Options ✨${NC}\n"
    printf "%s\n" "----------------------------------------"
    printf "1️⃣  Bypass MDM Protection\n"
    printf "2️⃣  System Reboot\n"
    printf "3️⃣  Emergency Shell\n"
    printf "4️⃣  Exit\n"
    printf "%s\n" "----------------------------------------"
    echo ""
    
    PS3=$'\n'"👉 Select operation (1-4): "
    select opt in "Bypass MDM Protection" "System Reboot" "Emergency Shell" "Exit"; do
        case $opt in
            "Bypass MDM Protection")
                printf "${YEL}🚀 Starting MDM bypass...${NC}\n"
                
                [ -d "/Volumes/Macintosh HD - Data" ] && diskutil rename "Macintosh HD - Data" "Data"
                
                create_temp_user || { printf "${RED}User creation failed.${NC}\n"; continue; }
                block_mdm_servers || { printf "${RED}Server blocking failed.${NC}\n"; continue; }
                remove_mdm_profiles || { printf "${RED}Profile removal failed.${NC}\n"; continue; }
                
                printf "${GRN}✅ Bypass complete! Close terminal and reboot.${NC}\n"
                break
                ;;
            "System Reboot")
                printf "${BLU}🔄 Rebooting...${NC}\n"
                reboot
                ;;
            "Emergency Shell")
                printf "${YEL}🛠️ Launching shell...${NC}\n"
                /bin/zsh
                ;;
            "Exit")
                printf "${GRN}👋 Exiting...${NC}\n"
                exit 0
                ;;
            *)
                printf "${RED}Invalid selection.${NC}\n"
                ;;
        esac
    done
}

main
