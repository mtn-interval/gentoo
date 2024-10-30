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



# Script header
echo -e "${CC_HEADER}────── Fetch  v0.08 ──────${CC_RESET}"
echo
pause

# Define Mountain Interval repository
base_url="https://raw.githubusercontent.com/mtn-interval/gentoo/main/scripts/"
files=("c__prepare.sh" "d__install.sh")

# Download each script from GitHub
for file in "${files[@]}"; do
    echo -e "${CC_TEXT}Downloading ${file}...${CC_RESET}"
    while true; do
        wget --no-cache --quiet --show-progress "${base_url}${file}"
        if [ $? -eq 0 ]; then
            break  # Break the loop if the download is successful
        else
            echo
            echo -e "${CC_ERROR}Failed to download ${file}.${CC_RESET}"
            while true; do
                read -p "$(echo -e "${CC_ERROR}Would you like to try downloading ${file} again? (y/n): ${CC_RESET}")" retry_option
                case $retry_option in
                    y|Y)
                        echo
                        echo -e "${CC_TEXT}Retrying download of ${file}...${CC_RESET}"
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
done
separator

# Make the downloaded scripts executable
echo -e "${CC_TEXT}Making the scripts executable...${CC_RESET}"
for file in "${files[@]}"; do
    if [[ -f $file ]]; then
        chmod +x "$file"
    else
        error "${file} not found."
    fi
done
echo -e "${CC_TEXT}Executable permissions granted.${CC_RESET}"
separator

# Proceed
if [[ -f c__prepare.sh ]]; then
    echo -e "${CC_TEXT}The system is ready to proceed.${CC_RESET}"
    read -p "$(echo -e "${CC_TEXT}Press Enter to continue...${CC_RESET}")"
    separator
    ./c__prepare.sh
else
    error "File not found."
    exit 1
fi