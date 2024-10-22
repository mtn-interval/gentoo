#!/bin/bash

# Automation script by Mountain Interval

# CC_TEXT codes for output
CC_HEADER='\033[1;35;44m'   # Bold Magenta on Blue background - To mark sections or major steps in the script.
CC_TEXT='\033[1;34;40m'     # Bold Blue on Black background - For general text, prompts, and success messages.
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




# Script header
echo -e "${CC_HEADER}────── Change root into the new system  v1.00 ──────${CC_RESET}"
echo
pause




# Installing a Gentoo ebuild repository snapshot from the web
echo -e "${CC_TEXT}Installing Gentoo ebuild repository snapshot using emerge-webrsync...${CC_RESET}"
emerge-webrsync
if [ $? -ne 0 ]; then
    echo
    echo "Failed to install Gentoo ebuild repository snapshot. Exiting."
    echo
    exit 1
fi
separator




# Choosing the right Gentoo profile
echo -e "${CC_TEXT}Listing available Gentoo profiles...${CC_RESET}"
eselect profile list | more

read -p "Enter the profile number to set: " profile_number

# Set the chosen profile
eselect profile set "$profile_number"
if [ $? -ne 0 ]; then
    echo
    echo "Failed to set the profile. Exiting."
    echo
    exit 1
fi
separator




# Updating the @world set
echo -e "${CC_TEXT}Updating the @world set...${CC_RESET}"
emerge --ask --verbose --update --deep --changed-use @world
if [ $? -ne 0 ]; then
    echo
    echo "Failed to update the @world set. Exiting."
    echo
    exit 1
fi
separator
