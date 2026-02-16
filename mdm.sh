#!/usr/bin/env bash

RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Logging function
log() {
    local level="$1"
    shift
    local msg="$@"
    case $level in
        INFO)  printf "${CYAN}[INFO]${NC} %s\n" "$msg" ;;
        OK)    printf "${GRN}[✓]${NC} %s\n" "$msg" ;;
        WARN)  printf "${YEL}[⚠]${NC} %s\n" "$msg" ;;
        ERROR) printf "${RED}[✗]${NC} %s\n" "$msg" ;;
        STEP)  printf "${BLU}[→]${NC} %s\n" "$msg" ;;
    esac
}

# Auto-detect volumes with detailed logging
detect_volumes() {
    log STEP "Starting volume detection..."
    
    log INFO "Scanning /Volumes directory..."
    ls -la /Volumes/ | while read line; do
        log INFO "  $line"
    done
    echo
    
    # Find Data volume
    log STEP "Detecting Data volume..."
    DATA_VOL=$(ls -d /Volumes/*Data* 2>/dev/null | head -n 1)
    if [ -z "$DATA_VOL" ]; then
        log WARN "Standard Data volume not found, searching alternatives..."
        DATA_VOL=$(find /Volumes -maxdepth 1 -type d -name "*Data" 2>/dev/null | head -n 1)
    fi
    
    if [ -n "$DATA_VOL" ]; then
        log OK "Data volume found: $DATA_VOL"
    else
        log ERROR "Data volume NOT FOUND"
    fi
    
    # Find System volume
    log STEP "Detecting System volume..."
    SYS_VOL=$(ls -d /Volumes/Preinstall 2>/dev/null)
    if [ -z "$SYS_VOL" ]; then
        log WARN "Preinstall not found, checking for Macintosh HD..."
        SYS_VOL=$(ls -d /Volumes/Macintosh* 2>/dev/null | grep -v Data | head -n 1)
    fi
    if [ -z "$SYS_VOL" ]; then
        log WARN "Macintosh HD not found, searching other volumes..."
        SYS_VOL=$(find /Volumes -maxdepth 1 -type d ! -name "*Data*" ! -name "macOS*" -name "*" 2>/dev/null | grep -v "^/Volumes/$" | head -n 1)
    fi
    
    if [ -n "$SYS_VOL" ]; then
        log OK "System volume found: $SYS_VOL"
    else
        log ERROR "System volume NOT FOUND"
    fi
    
    echo
    printf "${CYAN}╭──────────────────────────────────────────────╮${NC}\n"
    printf "${CYAN}│ ${GRN}Detected Volumes Summary${CYAN}                     │${NC}\n"
    printf "${CYAN}├──────────────────────────────────────────────┤${NC}\n"
    printf "${CYAN}│${NC} System: %-37s${CYAN}│${NC}\n" "${SYS_VOL:-NOT FOUND}"
    printf "${CYAN}│${NC} Data:   %-37s${CYAN}│${NC}\n" "${DATA_VOL:-NOT FOUND}"
    printf "${CYAN}╰──────────────────────────────────────────────╯${NC}\n\n"
    
    if [ -z "$SYS_VOL" ] || [ -z "$DATA_VOL" ]; then
        log ERROR "Critical: Cannot proceed without both volumes"
        log INFO "Available volumes:"
        ls -1 /Volumes/
        return 1
    fi
    
    # Verify critical paths
    log STEP "Verifying critical paths..."
    local dscl_path="$DATA_VOL/private/var/db/dslocal/nodes/Default"
    if [ -d "$dscl_path" ]; then
        log OK "DSCL path exists: $dscl_path"
    else
        log ERROR "DSCL path missing: $dscl_path"
    fi
    
    local hosts_file="$SYS_VOL/etc/hosts"
    if [ -f "$hosts_file" ]; then
        log OK "Hosts file exists: $hosts_file"
    else
        log ERROR "Hosts file missing: $hosts_file"
    fi
    
    local config_path="$SYS_VOL/var/db/ConfigurationProfiles/Settings"
    if [ -d "$config_path" ]; then
        log OK "Config path exists: $config_path"
    else
        log WARN "Config path missing: $config_path (will be created)"
    fi
    
    echo
}

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

create_temp_user() {
    local dscl_path="$DATA_VOL/private/var/db/dslocal/nodes/Default"
    
    log STEP "Creating temporary user account..."
    log INFO "Target DSCL path: $dscl_path"
    
    if [ ! -d "$dscl_path" ]; then
        log ERROR "DSCL path not found: $dscl_path"
        return 1
    fi
    
    read -p "👤 Enter temporary username (default: Apple): " username
    read -p "📝 Enter full name (default: Apple User): " fullname
    read -p "🔑 Enter password (default: 1234): " password
    
    : ${username:=Apple} ${fullname:=Apple User} ${password:=1234}
    
    log INFO "Username: $username"
    log INFO "Full name: $fullname"
    log INFO "Password: [HIDDEN]"
    
    log STEP "Creating user record..."
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" && log OK "User record created" || { log ERROR "Failed to create user"; return 1; }
    
    log STEP "Setting shell to /bin/zsh..."
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh" && log OK "Shell set" || log ERROR "Failed to set shell"
    
    log STEP "Setting real name..."
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$fullname" && log OK "Real name set" || log ERROR "Failed to set real name"
    
    log STEP "Setting UID to 501..."
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501" && log OK "UID set" || log ERROR "Failed to set UID"
    
    log STEP "Setting primary group to 20..."
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20" && log OK "Group set" || log ERROR "Failed to set group"
    
    log STEP "Creating home directory..."
    mkdir -p "$DATA_VOL/Users/$username" && log OK "Home directory created: $DATA_VOL/Users/$username" || log ERROR "Failed to create home"
    
    log STEP "Setting home directory path..."
    dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username" && log OK "Home path set" || log ERROR "Failed to set home path"
    
    log STEP "Setting password..."
    dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" "$password" && log OK "Password set" || log ERROR "Failed to set password"
    
    log STEP "Adding to admin group..."
    dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership "$username" && log OK "Added to admin group" || log ERROR "Failed to add to admin"
    
    log OK "User '$username' created successfully"
    echo
}

block_mdm_servers() {
    local hosts_file="$SYS_VOL/etc/hosts"
    
    log STEP "Blocking MDM servers..."
    log INFO "Target hosts file: $hosts_file"
    
    if [ ! -f "$hosts_file" ]; then
        log ERROR "Hosts file not found: $hosts_file"
        return 1
    fi
    
    log INFO "Current hosts file size: $(wc -l < "$hosts_file") lines"
    
    log STEP "Adding MDM server blocks..."
    {
        echo "0.0.0.0 deviceenrollment.apple.com"
        echo "0.0.0.0 mdmenrollment.apple.com"
        echo "0.0.0.0 iprofiles.apple.com"
        echo "0.0.0.0 gdmf.apple.com"
        echo "0.0.0.0 albert.apple.com"
    } >> "$hosts_file"
    
    if [ $? -eq 0 ]; then
        log OK "MDM servers blocked successfully"
        log INFO "New hosts file size: $(wc -l < "$hosts_file") lines"
        log INFO "Blocked servers:"
        log INFO "  - deviceenrollment.apple.com"
        log INFO "  - mdmenrollment.apple.com"
        log INFO "  - iprofiles.apple.com"
        log INFO "  - gdmf.apple.com"
        log INFO "  - albert.apple.com"
    else
        log ERROR "Failed to update hosts file"
        return 1
    fi
    echo
}

remove_mdm_profiles() {
    log STEP "Removing MDM profiles..."
    
    local config_path="$SYS_VOL/var/db/ConfigurationProfiles/Settings"
    log INFO "Config path: $config_path"
    
    log STEP "Removing .cloudConfig files..."
    if rm -rf "$config_path/.cloudConfig"* 2>/dev/null; then
        log OK "Removed .cloudConfig files"
    else
        log WARN "No .cloudConfig files found (may already be clean)"
    fi
    
    log STEP "Creating .cloudConfigProfileInstalled marker..."
    if touch "$config_path/.cloudConfigProfileInstalled"; then
        log OK "Marker created: $config_path/.cloudConfigProfileInstalled"
    else
        log ERROR "Failed to create marker"
    fi
    
    log STEP "Creating .AppleSetupDone marker..."
    if touch "$DATA_VOL/private/var/db/.AppleSetupDone"; then
        log OK "Marker created: $DATA_VOL/private/var/db/.AppleSetupDone"
    else
        log ERROR "Failed to create .AppleSetupDone"
    fi
    
    log OK "MDM profiles removed successfully"
    echo
}

main() {
    rm -- "$0" 2>/dev/null
    clear
    display_header

    # Detect volumes first
    detect_volumes || exit 1

    local serial
    serial=$(get_serial_number)
    if [ -z "$serial" ]; then
         serial="N/A"
    fi
    
    check_hardware

    printf "${CYAN}✨ Main Menu Options ✨${NC}\n"
    printf "%s\n" "----------------------------------------"
    printf "1️⃣  Bypass MDM Protection\n"
    printf "2️⃣  System Reboot\n"
    printf "3️⃣  Emergency Shell\n"
    printf "4️⃣  Exit\n"
    printf "%s\n" "----------------------------------------"
    echo ""

    PS3=$'\n'"👉 Please select an operation (1-4): "
    select opt in "Bypass MDM Protection" "System Reboot" "Emergency Shell" "Exit"; do
        case $opt in
            "Bypass MDM Protection")
                echo
                log STEP "Starting MDM bypass sequence..."
                echo "════════════════════════════════════════════════"
                echo
                
                create_temp_user || { log ERROR "User creation failed, aborting"; continue; }
                block_mdm_servers || { log ERROR "Server blocking failed, aborting"; continue; }
                remove_mdm_profiles || { log ERROR "Profile removal failed, aborting"; continue; }
                
                echo "════════════════════════════════════════════════"
                log OK "Bypass complete!"
                printf "${GRN}Please close the terminal and reboot the system.${NC}\n\n"
                break
                ;;
            "System Reboot")
                log INFO "Initiating system reboot..."
                reboot
                ;;
            "Emergency Shell")
                log INFO "Launching emergency shell..."
                /bin/zsh
                ;;
            "Exit")
                log INFO "Terminating session..."
                exit 0
                ;;
            *)
                log ERROR "Invalid selection. Please try again."
                ;;
        esac
    done
}

main
