#!/bin/bash

# Automation script by Mountain Interval

# CC_TEXT codes for output
CC_HEADER='\033[1;35;44m'   # Bold Magenta on Blue background - To mark sections or major steps in the script.
CC_TEXT='\033[1;34;40m'     # Bold Blue on Black background - For general text, prompts, and success messages.
CC_ERROR='\033[1;35;40m'     # Bold Magenta on Black background - For error messages.
CC_RESET='\033[0m'          # Reset CC_TEXT - To reset color coding.




# Function to pause the script
pause() {
    sleep 1
}




# Define text separator style
separator() {
    echo -e "${CC_TEXT}│${CC_RESET}"
    echo -e "${CC_TEXT}│${CC_RESET}"
    echo -e "${CC_TEXT}│${CC_RESET}"
}




# Clear screen
clear




# Script header
echo -e "${CC_HEADER}────── Gentoo Install Script  v1.00 ──────${CC_RESET}"
echo
pause




# Load keyboard layout
echo -e "${CC_TEXT}Loading portuguese keyboard layout...${CC_RESET}"
loadkeys pt-latin1
echo -e "${CC_TEXT}pt-latin1${CC_RESET}"
separator




# Function to configure network
configure_network() {
    while true; do
        echo -e "${CC_TEXT}1. Wired${CC_RESET}"
        echo -e "${CC_TEXT}2. Wireless${CC_RESET}"
        read -p "$(echo -e "${CC_TEXT}Choose your connection type: ${CC_RESET}")" connection_type

        if [[ "$connection_type" == "1" ]]; then
            echo -e "${CC_TEXT}You have chosen a wired connection. Skipping wi-fi setup...${CC_RESET}"
            break
        elif [[ "$connection_type" == "2" ]]; then
            echo -e "${CC_TEXT}You have chosen a wireless connection. Starting wi-fi setup...${CC_RESET}"

            # Prompt for SSID and connect using iwctl
            echo
            echo -e "${CC_TEXT}Connecting to wi-fi.${CC_RESET}"
            read -p "$(echo -e "${CC_TEXT}Please enter your wi-fi SSID: ${CC_RESET}")" ssid
            read -sp "$(echo -e "${CC_TEXT}Please enter the wi-fi password: ${CC_RESET}")" wifi_password
            iwctl station wlan0 connect "$ssid" --passphrase "$wifi_password"
            if [ $? -eq 0 ]; then
            	echo
                echo -e "${CC_TEXT}Connected to wi-fi successfully.${CC_RESET}"
                break
            else
                echo -e "${CC_ERROR}Failed to connect to wi-fi. Please check the SSID and try again.${CC_RESET}"
                echo
            fi
        else
            echo -e "${CC_ERROR}Invalid option.${CC_RESET}"
            echo
        fi
    done
    separator
}

# Call network configuration
configure_network




# Confirm internet connection
check_internet() {
    echo -e "${CC_TEXT}Checking internet connection...${CC_RESET}"
    for site in archlinux.org google.com; do
        if ping -c 1 "$site" &> /dev/null; then
            echo -e "${CC_TEXT}Internet connection confirmed.${CC_RESET}"
            return 0
        fi
    done
    return 1
}

if ! check_internet; then
    echo -e "${CC_ERROR}No internet connection detected.${CC_RESET}"
    while true; do
        read -p "$(echo -e "${CC_ERROR}No connection detected. Would you like to reconfigure the network? (y/n): ${CC_RESET}")" retry_option
        case $retry_option in
            y|Y)
                echo
                echo -e "${CC_TEXT}Reconfiguring network...${CC_RESET}"
                echo
                configure_network
                ;;
            n|N)
                echo
                echo -e "${CC_ERROR}Exiting...${CC_RESET}"
                echo
                exit 1
                ;;
            *)
                echo
                echo -e "${CC_ERROR}Please enter 'y' or 'n'.${CC_RESET}"
                echo
                ;;
        esac
        # Re-check internet connection after reconfiguration
        if check_internet; then
            break
        fi
    done
fi
separator




# Download the pre-install script
echo -e "${CC_TEXT}Downloading the pre-install script...${CC_RESET}"
while true; do
    wget --no-cache --quiet --show-progress https://raw.githubusercontent.com/mtn-interval/gentoo/main/01--pre.sh
    if [ $? -eq 0 ]; then
        echo -e "${CC_TEXT}Download successful.${CC_RESET}"
        break  # Break the loop if the download is successful
    else
        echo -e "${CC_ERROR}Failed to download the pre-install script.${CC_RESET}"
        while true; do
            read -p "$(echo -e "${CC_ERROR}Would you like to try downloading again? (y/n): ${CC_RESET}")" retry_option
            case $retry_option in
                y|Y)
                    echo
                    echo -e "${CC_TEXT}Retrying download...${CC_RESET}"
                    break  # Break the inner loop to retry the download
                    ;;
                n|N)
                    echo
                    echo -e "${CC_ERROR}Exiting...${CC_RESET}"
                    echo
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

    # Prompt for user to press Enter to continue
    echo -e "${CC_TEXT}The system is ready to proceed.${CC_RESET}"
    read -p "$(echo -e "${CC_TEXT}Press Enter to continue with the pre-install script...${CC_RESET}")"
    
    echo
    echo -e "${CC_TEXT}Running 01--pre.sh...${CC_RESET}"
    separator
    ./01--pre.sh
else
	echo
    echo -e "${CC_ERROR}File not found. Exiting...${CC_RESET}"
    echo
    exit 1
fi