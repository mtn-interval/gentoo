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


# Clear screen
clear

# Script header
echo -e "${CC_HEADER}────── Gentoo Install Script  v0.10 ──────${CC_RESET}"
echo

# Prompt the user to choose unattended or interactive mode
read -p "$(echo -e "${CC_TEXT}Do you want the installation process to be unattended? (y/n): ${CC_RESET}")" u_choice
if [[ "$u_choice" == "y" || "$u_choice" == "Y" ]]; then
    unattended=1
    echo -e "${CC_TEXT}Unattended mode selected.${CC_RESET}"
else
    unattended=0
    echo -e "${CC_TEXT}Interactive mode selected.${CC_RESET}"
fi
export unattended
separator

# Step labels and user prompt
declare -A steps
steps=(
    [1]="Set keyboard layout"
    [2]="Check network connection"
    [3]="Download Fetch script"
    # Add more steps as needed
)

# Generate a sorted list of step keys
sorted_steps=($(echo "${!steps[@]}" | tr ' ' '\n' | sort -n))

# Print the index of steps in sorted order
echo -e "${CC_TEXT}Available Steps:${CC_RESET}"
for step in "${sorted_steps[@]}"; do
    echo "[$step]: ${steps[$step]}"
done
echo

# Ask user if they want to resume
resume_choice=$(execute_if_not_unattended "${CC_TEXT}Do you want to resume from a specific step? (y/n): ${CC_RESET}" "n")
if [[ $resume_choice == "y" ]]; then
    read -p "$(echo -e "${CC_TEXT}Enter the step number to start from (1-${#steps[@]}): ${CC_RESET}")" start_step
else
    start_step=1
fi

# Loop through steps in sorted order
for step in "${sorted_steps[@]}"; do
    # Skip steps until reaching the desired starting step
    if (( step < start_step )); then
        continue
    fi
    
    echo -e "${CC_TEXT}[$step]: ${steps[$step]}${CC_RESET}"
    
    # Execute the corresponding commands for each step
    case $step in
        1)
            # Set keyboard layout to Portuguese (Latin-1)
            echo -e "${CC_TEXT}Setting keyboard layout to pt-latin1...${CC_RESET}"
            loadkeys pt-latin1
            check_error "Failed to set keyboard layout. Exiting."
            separator
            ;;
        2)
            # Verify network connection and perform basic network diagnostics
            echo -e "${CC_TEXT}Verifying network connection and performing basic diagnostics...${CC_RESET}"
            echo

            # Check the routing table
            echo -e "${CC_TEXT}Checking the routing table...${CC_RESET}"
            ip route
            check_error "Failed to retrieve routing table. Exiting."
            separator

            # Ping a known IP address to confirm connectivity
            echo -e "${CC_TEXT}Pinging 1.1.1.1 to test connectivity...${CC_RESET}"
            ping -c 3 1.1.1.1
            check_error "Ping test failed. Exiting."
            separator

            # Test HTTP connection to gentoo.org using curl
            echo -e "${CC_TEXT}Testing HTTP connection to gentoo.org...${CC_RESET}"
            curl --location gentoo.org --output /dev/null
            check_error "HTTP connection test to gentoo.org failed. Exiting."
            separator

            # Display IP address information
            echo -e "${CC_TEXT}Displaying IP address information...${CC_RESET}"
            ip address show
            check_error "Failed to display IP address information. Exiting."
            separator
            ;;
        3)
            # Download the pre-install script
            echo -e "${CC_TEXT}Downloading the Fetch script...${CC_RESET}"
            while true; do
                wget --no-cache --quiet --show-progress https://raw.githubusercontent.com/mtn-interval/gentoo/main/scripts/b__fetch.sh
                if [ $? -eq 0 ]; then
                    break
                else
                    error "Failed to download the Fetch script."
                    while true; do
                        read -p "$(echo -e "${CC_ERROR}Would you like to try downloading again? (y/n): ${CC_RESET}")" retry_option
                        case $retry_option in
                            y|Y)
                                echo
                                echo -e "${CC_TEXT}Retrying download...${CC_RESET}"
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
            separator

            # Make the script executable
            echo -e "${CC_TEXT}Making the script executable...${CC_RESET}"
            chmod +x b__fetch.sh
            check_error "Failed to set permissions. Exiting."
            echo -e "${CC_TEXT}Executable permission granted.${CC_RESET}"
            separator

            # Proceed
            if [[ -f b__fetch.sh ]]; then
                echo -e "${CC_TEXT}The system is ready to proceed.${CC_RESET}"
                separator
                ./b__fetch.sh
            else
                error "File not found. Exiting."
                exit 1
            fi
            ;;
        # Add more cases as needed
    esac

    # Delay between steps
    pause
done