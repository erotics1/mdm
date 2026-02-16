#!/bin/bash

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Function to retrieve serial number
get_serial_number() {
    local serialNumber
    # Try extracting using system_profiler
    serialNumber=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Serial Number" | head -n 1 | awk -F": " '{print $2}')
    
    # If not obtained, try using ioreg
    if [ -z "$serialNumber" ]; then
        serialNumber=$(ioreg -l | grep IOPlatformSerialNumber | awk -F'"' '{print $4}')
    fi
    
    # Trim whitespace
    serialNumber=$(echo "$serialNumber" | xargs)
    
    # If serial is valid (minimum 3 alphanumeric characters), return it; otherwise return "N/A"
    if [[ "$serialNumber" =~ ^[a-zA-Z0-9]{3,}$ ]]; then
         echo "$serialNumber"
    else
         echo "N/A"
    fi
}

# Display header with centered text and emojis
display_header() {
    local serial
    serial=$(get_serial_number)
    
    # Variables for the box
    local inner_width=46
    local title="🔐 i-RealmPRO MDM MacBook"
    local serial_line="Serial: $serial"
    local tool="Professional MDM Removal Tool 🚀"
    
    # Inline function to center text
    center_line() {
        local text="$1"
        local text_len=${#text}
        local pad=$(( (inner_width - text_len) / 2 ))
        local rem=$(( (inner_width - text_len) % 2 ))
        local left_pad=$(printf '%*s' "$pad" "")
        local right_pad=$(printf '%*s' $((pad + rem)) "")
        printf "%s%s%s" "$left_pad" "$text" "$right_pad"
    }
    
    printf "${GRN}╭──────────────────────────────────────────────╮${NC}\n"
    printf "${GRN}│${NC}$(center_line "$title")${GRN}│${NC}\n"
    printf "${GRN}│${NC}$(center_line "$serial_line")${GRN}│${NC}\n"
    printf "${GRN}│${NC}$(center_line "$tool")${GRN}│${NC}\n"
    printf "${GRN}╰──────────────────────────────────────────────╯${NC}\n\n"
}

# Hardware Information Check
check_hardware() {
    echo ""
    printf "${BLU}🖥️  Hardware Information:${NC}\n"
    printf "%s\n" "----------------------------------------"
    printf "📦 Model          : %s\n" "$(sysctl -n hw.model)"
    printf "🧩 Architecture   : %s\n" "$(uname -m)"
    printf "💻 macOS Version  : %s\n" "$(sw_vers -productVersion)"
    printf "🆔 UDID           : %s\n" "$(ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/ {print $3}' | tr -d \")"
    printf "%s\n" "----------------------------------------"
    echo ""
    printf "${CYAN}Note:${NC} The above hardware details are retrieved directly from your system configuration.\n"
    echo ""
}

# MDM Bypass functions
create_temp_user() {
    local dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
    
    read -p "👤 Enter temporary username (default: Apple): " username
    read -p "📝 Enter full name (default: Apple User): " fullname
    read -p "🔑 Enter password (default: 1234): " password
    
    : ${username:=Apple} ${fullname:=Apple User} ${password:=1234}
    
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
}

block_mdm_servers() {
    printf "${YEL}⛔ Blocking MDM servers...${NC}\n"
    {
        printf "0.0.0.0 deviceenrollment.apple.com\n"
        printf "0.0.0.0 mdmenrollment.apple.com\n"
        printf "0.0.0.0 iprofiles.apple.com\n"
        printf "0.0.0.0 gdmf.apple.com\n"
        printf "0.0.0.0 albert.apple.com\n"
    } >> "/Volumes/Macintosh HD/etc/hosts"
}

remove_mdm_profiles() {
    printf "${YEL}🧹 Removing MDM profiles...${NC}\n"
    rm -rf "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfig"*
    touch "/Volumes/Macintosh HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled"
    touch "/Volumes/Data/private/var/db/.AppleSetupDone"
}

# Main workflow
main() {
    rm -- "$0" 2>/dev/null
    clear
    display_header

    # Get serial number (if not obtained, use "N/A")
    local serial
    serial=$(get_serial_number)
    if [ -z "$serial" ]; then
         serial="N/A"
    fi
    
    check_hardware

    # Display a fancy menu header with emojis
    printf "${CYAN}✨ Main Menu Options ✨${NC}\n"
    printf "%s\n" "----------------------------------------"
    printf "1️⃣  Bypass MDM Protection\n"
    printf "2️⃣  System Reboot\n"
    printf "3️⃣  Emergency Shell\n"
    printf "4️⃣  Exit\n"
    printf "%s\n" "----------------------------------------"
    echo ""

    # User menu using select command with a customized prompt
    PS3=$'\n'"👉 Please select an operation (1-4): "
    select opt in "Bypass MDM Protection" "System Reboot" "Emergency Shell" "Exit"; do
        case $opt in
            "Bypass MDM Protection")
                printf "${YEL}🚀 Starting MDM bypass sequence...${NC}\n"
                [ -d "/Volumes/Macintosh HD - Data" ] && diskutil rename "Macintosh HD - Data" "Data"
                create_temp_user
                block_mdm_servers
                remove_mdm_profiles
                printf "${GRN}✅ Bypass complete!${NC} Please close the terminal and reboot the system.\n"
                ;;
            "System Reboot")
                printf "${BLU}🔄 Initiating system reboot...${NC}\n"
                reboot
                ;;
            "Emergency Shell")
                printf "${YEL}🛠️ Launching emergency shell...${NC}\n"
                /bin/zsh
                ;;
            "Exit")
                printf "${GRN}👋 Terminating session...${NC}\n"
                exit 0
                ;;
            *)
                printf "${RED}Invalid selection. Please try again.${NC}\n"
                ;;
        esac
    done
}

# Start execution
main