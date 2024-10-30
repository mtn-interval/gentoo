#!/bin/bash

# Automation script by Mountain Interval



# CC_TEXT codes for output
CC_HEADER='\033[1;35;44m'   # Bold Magenta on Blue background - To mark sections or major steps in the script.
CC_TEXT='\033[1;34;40m'     # Bold Blue on Black background - For general text, prompts, and success messages.
CC_ERROR='\033[1;35;40m'    # Bold Magenta on Black background - For error messages.
CC_RESET='\033[0m'          # Reset CC_TEXT - To reset color coding.

# Function to pause the script
pause() {
    sleep 2
}

# Define text separator style
separator() {
    echo -e "${CC_TEXT}│${CC_RESET}"
    echo -e "${CC_TEXT}│${CC_RESET}"
    echo -e "${CC_TEXT}│${CC_RESET}"
}

# Function to print error messages
error() {
    echo
    echo -e "${CC_ERROR}$1 Exiting.${CC_RESET}"
    echo
}

# Function to check exit status and handle errors
check_error() {
    if [ $? -ne 0 ]; then
        error "$1"
        exit 1
    fi
}

# Function to pause and optionally exit for debugging
breakscript() {
    echo -e "${CC_ERROR}──────────────────────────────────────────────────${CC_RESET}"
    echo -e "${CC_ERROR}  SCRIPT PAUSED. Press Enter to exit. ${CC_RESET}"
    echo -e "${CC_ERROR}──────────────────────────────────────────────────${CC_RESET}"
    read -p ""
    echo
    exit 1
}

# Clear screen
clear

# Script header
echo -e "${CC_HEADER}────── Gentoo Install Script  v0.07 ──────${CC_RESET}"
echo
pause

# Set keyboard layout to Portuguese (Latin-1)
echo -e "${CC_TEXT}Setting keyboard layout to pt-latin1...${CC_RESET}"
loadkeys pt-latin1
separator

# Verify network connection and perform basic network diagnostics
echo -e "${CC_TEXT}Verifying network connection and performing basic diagnostics...${CC_RESET}"

# Check the routing table
echo -e "${CC_TEXT}Checking the routing table...${CC_RESET}"
ip route
check_error "Failed to retrieve routing table."
separator

# Ping a known IP address to confirm connectivity
echo -e "${CC_TEXT}Pinging 1.1.1.1 to test connectivity...${CC_RESET}"
ping -c 3 1.1.1.1
check_error "Ping test failed."
separator

# Test HTTP connection to gentoo.org using curl
echo -e "${CC_TEXT}Testing HTTP connection to gentoo.org...${CC_RESET}"
curl --location gentoo.org --output /dev/null
check_error "HTTP connection test to gentoo.org failed."
separator

# Display IP address information
echo -e "${CC_TEXT}Displaying IP address information...${CC_RESET}"
ip address show
check_error "Failed to display IP address information."
separator

# Download the pre-install script
echo -e "${CC_TEXT}Downloading the pre-install script...${CC_RESET}"
while true; do
    wget --no-cache --quiet --show-progress https://raw.githubusercontent.com/mtn-interval/gentoo/main/scripts/01--pre.sh
    if [ $? -eq 0 ]; then
        break
    else
        echo -e "${CC_ERROR}Failed to download the pre-install script.${CC_RESET}"
        while true; do
            read -p "$(echo -e "${CC_ERROR}Would you like to try downloading again? (y/n): ${CC_RESET}")" retry_option
            case $retry_option in
                y|Y)
                    echo
                    echo -e "${CC_TEXT}Retrying download...${CC_RESET}"
                    break
                    ;;
                n|N)
                    error "Failed to download."
                    exit 1
                    ;;
                *)
                    echo
                    echo -e "${CC_ERROR}Please enter 'y' or 'n'.${CC_RESET}"
                    ;;
            esac
        done
    fi
done
separator

# Make the script executable
echo -e "${CC_TEXT}Making the script executable...${CC_RESET}"
chmod +x 01--pre.sh
echo -e "${CC_TEXT}Executable permission granted.${CC_RESET}"
separator

# Run pre-install
if [[ -f 01--pre.sh ]]; then
    echo -e "${CC_TEXT}The system is ready to proceed.${CC_RESET}"
    read -p "$(echo -e "${CC_TEXT}Press Enter to continue...${CC_RESET}")"
    
    echo
    echo -e "${CC_TEXT}Running 01--pre.sh...${CC_RESET}"
    separator
    ./01--pre.sh
else
    error "File not found."
    exit 1
fi