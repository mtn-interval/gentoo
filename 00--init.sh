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