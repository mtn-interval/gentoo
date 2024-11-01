#!/bin/bash

# Automation script by Mountain Interval



# CC_TEXT codes for output
CC_HEADER='\033[1;35;44m'   # Bold Magenta on Blue background - To mark sections or major steps in the script.
CC_TEXT='\033[1;36;40m'     # Bold Cyan on Black background - For general text, prompts, and success messages.
CC_ERROR='\033[1;35;40m'    # Bold Magenta on Black background - For error messages.
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

# Function to print error messages
error() {
    echo
    echo -e "${CC_ERROR}$1${CC_RESET}"
    echo
}

# Function to check exit status and handle errors
check_error() {
    if [ $? -ne 0 ]; then
        error "$1"
        exit 1
    fi
}

# Function to handle prompts based on the $unattended variable
execute_if_not_unattended() {
    local prompt_text="$1"
    local default_answer="$2"
    local user_answer

    if [[ "$unattended" -eq 1 ]]; then
        # Display the prompt text and default answer to stderr to avoid capturing it
        echo -e "${prompt_text} (Unattended mode: default answer '$default_answer')" >&2
        # Set user_answer to the default answer without echoing it
        user_answer="$default_answer"
    else
        # In interactive mode, prompt the user for input
        read -r -p "$(echo -e "$prompt_text")" user_answer
        # If the user enters nothing, use the default answer
        user_answer="${user_answer:-$default_answer}"
    fi

    # Return only the answer for capturing in the calling command
    echo "$user_answer"
}


########################################################################################


# Define Mountain Interval repository
base_url="https://raw.githubusercontent.com/mtn-interval/gentoo/main/scripts/"
files=("c__prepare.sh" "d__install.sh")

# Download each script from GitHub
for file in "${files[@]}"; do
    echo -e "${CC_TEXT}Downloading ${file}...${CC_RESET}"
    while true; do
        wget --no-cache --quiet --show-progress "${base_url}${file}"
        if [ $? -eq 0 ]; then
            break
        else
            error "Failed to download ${file}."
            while true; do
                read -p "$(echo -e "${CC_ERROR}Would you like to try downloading ${file} again? (y/n): ${CC_RESET}")" retry_option
                case $retry_option in
                    y|Y)
                        echo
                        echo -e "${CC_TEXT}Retrying download of ${file}...${CC_RESET}"
                        break
                        ;;
                    n|N)
                        error "Failed to download. Exiting."
                        exit 1
                        ;;
                    *)
                        error "Please enter 'y' or 'n'."
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
        check_error "Failed to set permissions. Exiting."
    else
        error "${file} not found. Exiting."
        exit 1
    fi
done
echo -e "${CC_TEXT}Executable permissions granted.${CC_RESET}"
separator

# Proceed
if [[ -f c__prepare.sh ]]; then
    echo -e "${CC_TEXT}The system is ready to proceed.${CC_RESET}"
    separator
    export unattended
    ./c__prepare.sh
else
    error "File not found. Exiting."
    exit 1
fi