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




# Function to pause and optionally exit for debugging
breakscript() {
    echo -e "${CC_ERROR}──────────────────────────────────────────────────${CC_RESET}"
    echo -e "${CC_ERROR}  SCRIPT PAUSED. Press Enter to exit. ${CC_RESET}"
    echo -e "${CC_ERROR}──────────────────────────────────────────────────${CC_RESET}"
    read -p ""
    echo
    exit 1
}




# Script header
echo -e "${CC_HEADER}────── Change root into the new system  v0.04 ──────${CC_RESET}"
echo
pause




# Installing a Gentoo ebuild repository snapshot from the web
echo -e "${CC_TEXT}Installing Gentoo ebuild repository snapshot using emerge-webrsync...${CC_RESET}"
emerge-webrsync
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install Gentoo ebuild repository snapshot. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Synchronize the Portage tree
echo -e "${CC_TEXT}Synchronizing the Portage tree with emerge --sync...${CC_RESET}"
emerge --sync
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to synchronize the Portage tree. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Install tmux
echo -e "${CC_TEXT}Installing tmux...${CC_RESET}"
emerge app-misc/tmux
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install tmux. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Start a new tmux session named "mtn-interval"
echo -e "${CC_TEXT}Starting a new tmux session named 'mtn-interval'...${CC_RESET}"
tmux new -s mtn-interval "bash ~/04--tmux.sh"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to start tmux session 'mtn-interval'. Exiting.${CC_RESET}"
    echo
    exit 1
fi




# Start a new tmux session named "reboot"
echo -e "${CC_TEXT}Starting a new tmux session named 'mtn-interval'...${CC_RESET}"
tmux new -s reboot "bash ~/05--reboot.sh"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to start tmux session 'reboot'. Exiting.${CC_RESET}"
    echo
    exit 1
fi