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
echo "unnatended variable is -----------> $unattended"

# Step labels and user prompt
declare -A steps
steps=(
    [1]="Partition"
    [2]="Syncronize clock"
    [3]="Download Stage3 tarball"
    [4]="Configure installation"
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
            # List available disks
            while true; do
                echo -e "${CC_TEXT}Available Disks:${CC_RESET}"
                echo
                lsblk -d -o NAME,SIZE,TYPE | grep disk
                echo

                # Prompt the user to select a disk
                disk=$(execute_if_not_unattended "${CC_TEXT}Please enter the disk you want to use (e.g., sda): ${CC_RESET}" "sda")

                # Check if the selected disk is valid
                if lsblk -d -n -o NAME | grep -qw "$disk"; then
                    echo -e "${CC_TEXT}Valid disk selected: /dev/$disk${CC_RESET}"
                    break 
                else
                    error "Invalid disk selected: $disk. Please try again."
                fi
            done

            # Confirm the choice and warn about data erasure
            echo
            echo -e "${CC_TEXT}Warning: All data on /dev/$disk will be erased!${CC_RESET}"            
            while true; do
                confirm=$(execute_if_not_unattended "${CC_TEXT}Are you sure you want to continue? (y/n): ${CC_RESET}" "y")
                case $confirm in
                    y|Y)
                        break
                        ;;
                    n|N)
                        error "Exiting without making any changes."
                        exit 1
                        ;;
                    *)
                        echo
                        echo -e "${CC_TEXT}Please enter 'y' or 'n'.${CC_RESET}"
                        ;;
                esac
            done
            separator

            # Detect and wipe all existing partitions using wipefs
            echo -e "${CC_TEXT}Detecting and wiping filesystem signatures from all partitions on /dev/$disk...${CC_RESET}"

            # Get list of partitions with a robust grep pattern
            partitions=$(lsblk -ln -o NAME /dev/$disk | grep -E "^${disk}[0-9]+$")

            # Debug: Print detected partitions for verification
            echo
            echo "$partitions"
            echo

            # Check if any partitions were found
            if [ -z "$partitions" ]; then
                echo -e "${CC_TEXT}No partitions found on /dev/$disk.${CC_RESET}"
            else
                for partition in $partitions; do
                    # Ensure we are passing full /dev/ path to wipefs
                    wipefs -fa "/dev/$partition"  # Correct usage with full path for each partition
                    check_error "Failed to wipe /dev/$partition. Exiting."
                done
            fi
            separator

            # Partition the disk using fdisk
            echo -e "${CC_TEXT}Starting automatic partitioning of /dev/$disk...${CC_RESET}"
            (
            echo o      # Create a new empty DOS partition table
            echo n      # Add a new partition
            echo p      # Primary partition
            echo 1      # Partition number 1
            echo        # Default - first sector
            echo +1G    # Assign 1GB to the boot partition
            echo a      # Make partition bootable
            echo n      # Add a new partition
            echo p      # Primary partition
            echo 2      # Partition number 2
            echo        # Default
            echo +4G    # Assign 4GB to the swap partition
            echo t      # Define swap partition type
            echo 2
            echo 82
            echo n      # Add a new partition
            echo p      # Primary partition
            echo 3      # Partition number 3
            echo        # Default
            echo        # Default - last sector (use full disk)
            echo p      # Show list of partitions
            echo w      # Write changes
            ) | fdisk --color=never /dev/$disk
            check_error "Partitioning failed on /dev/$disk. Exiting."
            echo -e "${CC_TEXT}Partitioning complete on /dev/$disk.${CC_RESET}"
            separator

            # Formatting the partitions
            echo -e "${CC_TEXT}Formatting /dev/${disk}1 as Ext4 (boot partition)...${CC_RESET}"
            mkfs.ext4 /dev/${disk}1
            check_error "Failed to format /dev/${disk}1. Exiting."
            echo -e "${CC_TEXT}Formatting /dev/${disk}3 as Ext4 (root partition)...${CC_RESET}"
            mkfs.ext4 /dev/${disk}3
            check_error "Failed to format /dev/${disk}3. Exiting."
            separator

            # Activating the swap partition
            echo -e "${CC_TEXT}Setting up and activating swap on /dev/${disk}2...${CC_RESET}"
            mkswap /dev/${disk}2
            check_error "Failed to set up swap on /dev/${disk}2. Exiting."
            swapon /dev/${disk}2
            check_error "Failed to activate swap on /dev/${disk}2. Exiting."
            separator

            # Mounting partitions
            echo -e "${CC_TEXT}Mounting root partition (/dev/${disk}3) to /mnt/gentoo...${CC_RESET}"
            mkdir -p /mnt/gentoo
            mount /dev/${disk}3 /mnt/gentoo
            check_error "Failed to mount /dev/${disk}3. Exiting."

            echo -e "${CC_TEXT}Mounting boot partition (/dev/${disk}1) to /mnt/gentoo/boot...${CC_RESET}"
            mkdir -p /mnt/gentoo/boot
            mount /dev/${disk}1 /mnt/gentoo/boot
            check_error "Failed to mount /dev/${disk}1. Exiting."
            separator
            ;;
        2)
            # Synchronizing the system clock
            echo -e "${CC_TEXT}Synchronizing the system clock using chronyd...${CC_RESET}"
            date
            chronyd -q
            check_error "Failed to synchronize the system clock. Exiting."
            date
            separator
            ;;
        3)
            # Check the value of $unnatended
            if [[ "$unnatended" -eq 0 ]]; then
                # Downloading the Stage 3 tarball
                echo -e "${CC_TEXT}Navigating to Gentoo mirrors to download the latest Stage 3 tarball...${CC_RESET}"
                cd /mnt/gentoo
                echo -e "${CC_TEXT}Launching links browser. Please navigate to the latest Stage 3 release, press 'd' to download.${CC_RESET}"
                pause
                links https://ftp.rnl.tecnico.ulisboa.pt/pub/gentoo/gentoo-distfiles/releases/amd64/autobuilds/
                echo -e "${CC_TEXT}Exiting links browser. Proceeding with the installation...${CC_RESET}"
                separator
            else
                echo -e "${CC_TEXT}Unattended mode enabled. Downloading latest *.tar.xz file...${CC_RESET}"

                # URL of the directory containing the tar.xz files
                base_url="https://ftp.rnl.tecnico.ulisboa.pt/pub/gentoo/gentoo-distfiles/releases/amd64/autobuilds/current-stage3-amd64-musl/"

                # Fetch the list of files and filter for the one ending in .tar.xz (excluding .tar.xz.asc and similar)
                file_name=$(curl -s "$base_url" | grep -oP 'stage3-.*?\.tar\.xz(?=")' | head -n 1)
                
                # Check if a file was found
                if [[ -z "$file_name" ]]; then
                    error "No .tar.xz file found in the specified directory. Exiting."
                    exit 1
                fi

                # Download the selected .tar.xz file
                wget "${base_url}${file_name}" -P ~/
                check_error "Failed to download the .tar.xz file. Exiting."
                
                echo -e "${CC_TEXT}Downloaded ${file_name} successfully.${CC_RESET}"
            fi

            # Unpacking the Stage 3 tarball
            echo -e "${CC_TEXT}Unpacking the Stage 3 tarball...${CC_RESET}"
            cd /mnt/gentoo
            tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner -C /mnt/gentoo
            check_error "Failed to unpack the Stage 3 tarball. Exiting."
            echo
            echo -e "${CC_TEXT}Unpacking complete.$disk.${CC_RESET}"
            separator 
            ;;
        4)
            # Prompt the user to enable or disable Distributed Compiling
            use_distributed=$(execute_if_not_unattended "${CC_TEXT}Would you like to use Distributed Compiling? (y/n): ${CC_RESET}" "n")

            if [[ "$use_distributed" =~ ^[Yy]$ ]]; then
                distributed=1
                echo -e "${CC_TEXT}Distributed Compiling enabled.${CC_RESET}"
                
                # Ask for local and remote cores
                read -p "$(echo -e "${CC_TEXT}Enter the number of local CPU cores: ${CC_RESET}")" local_cores
                read -p "$(echo -e "${CC_TEXT}Enter the number of remote CPU cores: ${CC_RESET}")" remote_cores

                # Calculate total jobs
                jobs=$(( (2 * (local_cores + remote_cores)) + 1 ))
                echo -e "${CC_TEXT}Jobs set to: $jobs${CC_RESET}"
            else
                distributed=0
                echo -e "${CC_TEXT}Distributed Compiling disabled.${CC_RESET}"
                
                # Ask for local cores only
                local_cores=$(execute_if_not_unattended "${CC_TEXT}Enter the number of local CPU cores: ${CC_RESET}" "2")

                # Set jobs to local cores
                jobs=$local_cores
                echo -e "${CC_TEXT}Jobs set to: $jobs${CC_RESET}"
            fi

            # Export the variable to make it available to other scripts
            export distributed
            separator

            # Configuring compile options in make.conf
            echo -e "${CC_TEXT}Configuring compile options in /mnt/gentoo/etc/portage/make.conf...${CC_RESET}"

            # Append additional options to the file
            cat <<EOL >> /mnt/gentoo/etc/portage/make.conf

# CUSTOM ThinkPad

GENTOO_MIRRORS="https://ftp.rnl.tecnico.ulisboa.pt/pub/gentoo/gentoo-distfiles/"
ACCEPT_LICENSE="*"

VIDEO_CARDS="intel"
INPUT_DEVICES="libinput synaptics"
CPU_FLAGS_X86="mmx mmxext sse sse2 sse3 ssse3"
MICROCODE_SIGNATURES="-s 0x000006fd"
USE="-gnome -kde -xfce -bluetooth -systemd"
EMERGE_DEFAULT_OPTS="--quiet-build=y"
EOL
            check_error "Failed to configure /mnt/gentoo/etc/portage/make.conf. Exiting."

            # Check if the distributed variable is set and append the appropriate FEATURES to make.conf
            if [[ "$distributed" -eq 0 ]]; then
            cat <<EOL >> /mnt/gentoo/etc/portage/make.conf

MAKEOPTS="-j$jobs"
FEATURES="parallel-fetch"
EOL
            check_error "Failed to configure /mnt/gentoo/etc/portage/make.conf. Exiting."
            elif [[ "$distributed" -eq 1 ]]; then
cat <<EOL >> /mnt/gentoo/etc/portage/make.conf

MAKEOPTS="-j$jobs -l$local_cores"
FEATURES="parallel-fetch distcc"
EOL
            check_error "Failed to configure /mnt/gentoo/etc/portage/make.conf. Exiting."
            else
                error "Error: Unknown value for distributed variable. Exiting."
                exit 1
            fi

            # Prompt user to make changes to make.conf
            change_conf=$(execute_if_not_unattended "${CC_TEXT}Do you want to make any changes to /mnt/gentoo/etc/portage/make.conf? (y/n): ${CC_RESET}" "n")
            if [[ "$change_conf" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /mnt/gentoo/etc/portage/make.conf in nano...${CC_RESET}"
                nano /mnt/gentoo/etc/portage/make.conf
            else
                echo -e "${CC_TEXT}No changes made to make.conf.${CC_RESET}"
            fi
            separator

            # Copy DNS info
            echo -e "${CC_TEXT}Copying DNS information to /mnt/gentoo/etc/...${CC_RESET}"
            cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
            check_error "Failed to copy DNS information. Exiting."
            separator

            # Copy necessary install scripts to the new system
            echo -e "${CC_TEXT}Copying installation scripts to /mnt/gentoo/root...${CC_RESET}"
            cd ~
            cp *__*.sh /mnt/gentoo/root
            check_error "Failed to copy installation scripts. Exiting."
            separator

            # Proceed
            if [[ -f d__install.sh ]]; then
                echo -e "${CC_TEXT}The system is ready to proceed.${CC_RESET}"
                separator

                # Change root into the new environment and run the chroot script
                echo -e "${CC_TEXT}Entering the chroot environment...${CC_RESET}"
                separator
                v_unattended="$unattended" v_jobs="$jobs" v_distributed="$distributed" arch-chroot /mnt/gentoo ~/d__install.sh
                check_error "Failed to chroot into the new environment. Exiting."
                separator
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