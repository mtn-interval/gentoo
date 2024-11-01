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

    if [[ "$v_unattended" -eq 1 ]]; then
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


# Step labels and user prompt
declare -A steps
steps=(
    [1]="Sync repository"
    [2]="Configure COMMON_FLAGS"
    [3]="Configure distributed compiling"
    [4]="Select Gentoo profile"
    [5]="Update @world set"
    [6]="Set timezone and locale"
    [7]="Install firmware"
    [8]="Configure installkernel"
    [9]="Install Gentoo kernel sources"
    [10]="Collect system information"
    [11]="Configure the kernel"
    [12]="Compile the kernel"
    [13]="Install the kernel"
    [14]="Configure fstab"
    [15]="Configure network"
    [16]="Configure system"
    [17]="Set the root password"
    [18]="Install basic services and tools"
    [19]="Install GRUB"
    [20]="Set up new user"
    [21]="Clean up"
    [22]="Exit chroot environment"
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
            # Installing a Gentoo ebuild repository snapshot from the web
            echo -e "${CC_TEXT}Installing Gentoo ebuild repository snapshot using emerge-webrsync...${CC_RESET}"
            emerge-webrsync
            check_error "Failed to install Gentoo ebuild repository snapshot. Exiting."
            separator

            # Sync the Portage tree and capture the output while displaying it
            echo -e "${CC_TEXT}Synchronizing the Portage tree with emerge --sync...${CC_RESET}"
            sync_output=$(emerge --sync 2>&1 | tee /dev/tty)
            check_error "Failed to synchronize the Portage tree. Exiting."
            separator

            # Check if there's an update available for Portage
            if echo "$sync_output" | grep -iq "an update to portage is available"; then
                # Prompt the user to update Portage
                update_portage=$(execute_if_not_unattended "${CC_TEXT}An update to Portage is available. Would you like to update it now? (y/n): ${CC_RESET}" "y")
                if [[ "$update_portage" =~ ^[Yy]$ ]]; then
                    echo -e "${CC_TEXT}Updating Portage...${CC_RESET}"
                    emerge --oneshot sys-apps/portage
                    check_error "Failed to update Portage. Exiting."
                    echo -e "${CC_TEXT}Portage updated successfully.${CC_RESET}"
                else
                    echo -e "${CC_TEXT}Portage update skipped by user.${CC_RESET}"
                fi
            else
                echo -e "${CC_TEXT}No Portage update needed.${CC_RESET}"
            fi
            separator
            ;;
        2)
            # Install resolve-march-native
            echo -e "${CC_TEXT}Installing app-misc/resolve-march-native...${CC_RESET}"
            emerge app-misc/resolve-march-native
            check_error "Failed to install resolve-march-native. Exiting."

            # Run resolve-march-native and save the output to a variable
            recommended_flags=$(resolve-march-native --add-recommended)
            check_error "Failed to run resolve-march-native. Exiting."

            # Update COMMON_FLAGS in /etc/portage/make.conf
            echo -e "${CC_TEXT}Updating COMMON_FLAGS in /etc/portage/make.conf...${CC_RESET}"
            sed -i "s/^COMMON_FLAGS=.*/COMMON_FLAGS=\"$recommended_flags\"/" /etc/portage/make.conf
            check_error "Failed to update COMMON_FLAGS in make.conf. Exiting"
            echo -e "${CC_TEXT}COMMON_FLAGS updated successfully to: $recommended_flags${CC_RESET}"
            separator

            # Unmerge resolve-march-native
            echo -e "${CC_TEXT}Uninstalling app-misc/resolve-march-native...${CC_RESET}"
            emerge --unmerge app-misc/resolve-march-native
            check_error "Failed to uninstall resolve-march-native. Exiting"
            separator
            ;;
        3)
            # Check if distributed compiling is enabled
            if [[ "$v_distributed" -eq 1 ]]; then
                echo -e "${CC_TEXT}Distributed compiling enabled. Setting up distcc...${CC_RESET}"

                # Install distcc
                emerge sys-devel/distcc
                check_error "Failed to install distcc. Exiting."

                # Add distccd to default runlevel and start the service
                rc-update add distccd default
                check_error "Failed to add distccd to default runlevel. Exiting."
                # rc-service distccd start
                # check_error "Failed to start distccd. Exiting"

                # Prompt user for the distribution host's IP address
                read -p "$(echo -e "${CC_TEXT}Enter the IP address of the distribution host: ${CC_RESET}")" distcc_host_ip

                # Prompt the user if they want localhost to participate
                read -p "$(echo -e "${CC_TEXT}Should localhost participate in distributed compiling? (y/n): ${CC_RESET}")" use_localhost
                if [[ "$use_localhost" =~ ^[Yy]$ ]]; then
                    /usr/bin/distcc-config --set-hosts "localhost $distcc_host_ip"
                    check_error "Failed to set distcc hosts with localhost included. Exiting."
                    echo -e "${CC_TEXT}Configured distcc with localhost and distribution host ${distcc_host_ip}.${CC_RESET}"
                else
                    /usr/bin/distcc-config --set-hosts "$distcc_host_ip"
                    check_error "Failed to set distcc hosts without localhost. Exiting."
                    echo -e "${CC_TEXT}Configured distcc with distribution host ${distcc_host_ip} only.${CC_RESET}"
                fi

                # # Add distcc to PATH
                # export PATH="/usr/lib/distcc/bin:${PATH}"
                # echo -e "${CC_TEXT}distcc configured successfully and PATH updated.${CC_RESET}"

            else
                echo -e "${CC_TEXT}Distributed compiling is disabled. Skipping distcc setup.${CC_RESET}"
            fi
            separator
            ;;
        4)
            # Choosing the right Gentoo profile
            echo -e "${CC_TEXT}Listing available Gentoo profiles...${CC_RESET}"
            eselect profile list | more
            echo
            profile_number=$(execute_if_not_unattended "${CC_TEXT}Enter the profile number to set: ${CC_RESET}" "1")

            # Set the chosen profile
            eselect profile set "$profile_number"
            check_error "Failed to set the profile. Exiting."
            separator
            ;;
        5)
            # Prompt user to update the @world set
            update_world=$(execute_if_not_unattended "${CC_TEXT}Do you want to update the @world set? (y/n): ${CC_RESET}" "y")
            if [[ "$update_world" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Updating the @world set...${CC_RESET}"
                emerge --verbose --update --deep --changed-use @world
                check_error "Failed to update the @world set. Exiting."

                # Clean up unnecessary dependencies after the @world update
                echo -e "${CC_TEXT}Cleaning up unnecessary dependencies with emerge --depclean...${CC_RESET}"
                emerge --depclean
                check_error "Failed to clean up dependencies. Exiting."

                # Run emerge @preserve only if depclean was successful
                echo -e "${CC_TEXT}Checking if any packages need to be rebuilt with emerge @preserve...${CC_RESET}"
                emerge @preserved-rebuild
                check_error "Failed to rebuild preserved libraries or packages. Exiting."

            else
                echo -e "${CC_TEXT}Skipping @world update, dependency cleanup, and rebuild check.${CC_RESET}"
            fi
            separator
            ;;
        6)
            # Detect if the Stage 3 tarball filename in root contains "musl"
            stage3_tarball=$(ls /stage3-*.tar.* 2>/dev/null | head -n 1)  # Detect the tarball file in the root directory

            if [[ -z "$stage3_tarball" ]]; then
                error "Stage 3 tarball not found in the root directory. Exiting."
                exit 1
            fi

            if echo "$stage3_tarball" | grep -iq "musl"; then
                echo -e "${CC_TEXT}Detected musl Stage 3 tarball...${CC_RESET}"
                echo

                # Install timezone data
                echo -e "${CC_TEXT}Installing timezone data package...${CC_RESET}"
                emerge sys-libs/timezone-data
                check_error "Failed to install timezone data. Exiting."
                separator

                # Set timezone to Europe/Lisbon
                echo -e "${CC_TEXT}Setting timezone to Europe/Lisbon...${CC_RESET}"
                printf 'TZ="%s"' "$(cat /usr/share/zoneinfo/Europe/Lisbon | tail -n 1)" | tee /etc/env.d/00local
                check_error "Failed to set timezone. Exiting."
                separator

                # Update environment and source profile
                echo -e "${CC_TEXT}Updating environment and sourcing profile...${CC_RESET}"
                env-update && source /etc/profile
                check_error "Failed to update environment. Exiting."
                echo
                date
                separator

                # Uninstall timezone data package
                echo -e "${CC_TEXT}Removing timezone data package...${CC_RESET}"
                emerge --unmerge sys-libs/timezone-data
                check_error "Failed to remove timezone data package. Exiting."
                separator
            else
                echo -e "${CC_TEXT}No musl Stage 3 tarball detected...${CC_RESET}"
                echo
                # Setting the system timezone to Europe/Lisbon
                echo -e "${CC_TEXT}Setting system timezone to Europe/Lisbon...${CC_RESET}"
                ln -sf ../usr/share/zoneinfo/Europe/Lisbon /etc/localtime
                check_error "Failed to set the system timezone. Exiting."
                separator

                # Define locales
                echo -e "${CC_TEXT}Uncommenting en_US.UTF-8 and pt_PT.UTF-8 in /etc/locale.gen...${CC_RESET}"
                sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
                check_error "Failed to uncomment locales in /etc/locale.gen. Exiting."
                separator

                # Generate locales
                echo -e "${CC_TEXT}Generating locales...${CC_RESET}"
                locale-gen
                check_error "Failed to generate locales. Exiting."
                separator

                # Listing available locales
                echo -e "${CC_TEXT}Listing available locales...${CC_RESET}"
                eselect locale list

                # Prompting user for the locale number
                locale_number=$(execute_if_not_unattended "${CC_TEXT}Enter the number corresponding to your desired locale: ${CC_RESET}" "en_US.UTF-8")

                # Setting the selected locale
                echo -e "${CC_TEXT}Setting the selected locale...${CC_RESET}"
                eselect locale set "$locale_number"
                check_error "Failed to set the locale. Exiting."
                separator

                # Updating environment and sourcing profile
                echo -e "${CC_TEXT}Updating environment and sourcing /etc/profile...${CC_RESET}"
                env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
                check_error "Failed to update environment and source profile. Exiting."
                separator
            fi 
            ;;
        7)
            # Prompt the user if they want to install linux-firmware
            install_linux_firmware=$(execute_if_not_unattended "${CC_TEXT}Would you like to install linux-firmware? (y/n): ${CC_RESET}" "y")
            if [[ "$install_linux_firmware" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing linux-firmware...${CC_RESET}"
                emerge sys-kernel/linux-firmware
                check_error "Failed to install linux-firmware. Exiting."
                echo -e "${CC_TEXT}linux-firmware installed successfully.${CC_RESET}"
            else
                echo -e "${CC_TEXT}Skipping installation of linux-firmware.${CC_RESET}"
            fi
            separator

            # Prompt the user if they want to install intel-microcode
            install_intel_microcode=$(execute_if_not_unattended "${CC_TEXT}Would you like to install intel-microcode? (y/n): ${CC_RESET}" "y")
            if [[ "$install_intel_microcode" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing intel-microcode...${CC_RESET}"
                emerge sys-firmware/intel-microcode
                check_error "Failed to install intel-microcode. Exiting."
                echo -e "${CC_TEXT}intel-microcode installed successfully.${CC_RESET}"
            else
                echo -e "${CC_TEXT}Skipping installation of intel-microcode.${CC_RESET}"
            fi
            separator
            ;;
        8)
            # Configure installkernel to use GRUB
            echo -e "${CC_TEXT}Configuring installkernel to use GRUB...${CC_RESET}"
            echo "sys-kernel/installkernel grub dracut" > /etc/portage/package.use/installkernel
            check_error "Failed to configure installkernel for GRUB. Exiting."
            separator

            # Install the installkernel package
            echo -e "${CC_TEXT}Installing sys-kernel/installkernel package...${CC_RESET}"
            emerge sys-kernel/installkernel
            check_error "Failed to install sys-kernel/installkernel. Exiting."
            separator
            ;;
        9)
            # Install Gentoo kernel sources
            echo -e "${CC_TEXT}Installing Gentoo kernel sources...${CC_RESET}"
            emerge sys-kernel/gentoo-sources
            check_error "Failed to install gentoo-sources. Exiting."
            separator

            # List available kernels
            echo -e "${CC_TEXT}Listing available kernel versions...${CC_RESET}"
            eselect kernel list
            check_error "Failed to list kernel versions. Exiting."
            echo

            # Prompt the user to select a kernel
            while true; do
                kernel_number=$(execute_if_not_unattended "${CC_TEXT}Please enter the number of the kernel version you want to set: ${CC_RESET}" "1")
                if [[ "$kernel_number" =~ ^[0-9]+$ ]]; then
                    echo -e "${CC_TEXT}Setting kernel version $kernel_number...${CC_RESET}"
                    eselect kernel set "$kernel_number"
                    if [ $? -eq 0 ]; then
                        echo
                        echo -e "${CC_TEXT}Kernel version $kernel_number has been set.${CC_RESET}"
                        break
                    else
                        error "Failed to set kernel version $kernel_number. Please try again."
                    fi
                else
                    error "Invalid input. Please enter a valid number."
                fi
            done
            separator

            # Verify the kernel symlink
            echo -e "${CC_TEXT}Setting the /usr/src/linux symlink...${CC_RESET}"
            ls -l /usr/src/linux
            check_error "Failed to set /usr/src/linux symlink. Exiting."
            separator

            # Prompt the user if they want to install dev-util/pahole
            install_pahole=$(execute_if_not_unattended "${CC_TEXT}Would you like to install dev-util/pahole? (y/n): ${CC_RESET}" "y")
            if [[ "$install_pahole" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing dev-util/pahole...${CC_RESET}"
                emerge dev-util/pahole
                check_error "Failed to install dev-util/pahole. Exiting."
                echo -e "${CC_TEXT}dev-util/pahole installed successfully.${CC_RESET}"
            else
                echo -e "${CC_TEXT}Skipping installation of dev-util/pahole.${CC_RESET}"
            fi
            separator
            ;;
        10)
            # Install pciutils package
            echo -e "${CC_TEXT}Installing pciutils package for lspci command...${CC_RESET}"
            emerge sys-apps/pciutils
            check_error "Failed to install pciutils. Exiting."
            separator

            # Create a directory for system information and collect hardware details
            echo -e "${CC_TEXT}Creating directory ~/system_info and collecting system information...${CC_RESET}"
            mkdir -p ~/system_info
            check_error "Failed to create ~/system_info directory. Exiting."

            # Collect system information
            lscpu > ~/system_info/lscpu_output.txt
            check_error "Failed to collect CPU information. Exiting."

            lspci > ~/system_info/lspci_output.txt
            check_error "Failed to collect PCI device information. Exiting."

            lsmod > ~/system_info/lsmod_output.txt
            check_error "Failed to collect loaded module information. Exiting."
            echo -e "${CC_TEXT}System information has been saved to ~/system_info directory.${CC_RESET}"
            separator
            ;;
        11)
            # Generate a minimal kernel configuration based on loaded modules
            echo -e "${CC_TEXT}Generating a minimal kernel configuration based on currently loaded modules with make localmodconfig...${CC_RESET}"
            cd /usr/src/linux
            make localmodconfig
            check_error "Failed to generate minimal kernel configuration. Exiting."
            separator

            # Open the kernel configuration menu for customization
            echo -e "${CC_TEXT}Opening kernel configuration menu with make nconfig...${CC_RESET}"
            make nconfig
            check_error "Failed to open kernel configuration menu. Exiting."
            separator 
            ;;
        12)
            # Build the kernel
            echo -e "${CC_TEXT}Building the kernel with make...${CC_RESET}"
            make 
            check_error "Kernel build failed. Exiting."
            separator

            # Install kernel modules
            echo -e "${CC_TEXT}Installing kernel modules with make modules_install...${CC_RESET}"
            make modules_install
            check_error "Failed to install kernel modules. Exiting."
            separator
            ;;
        13)
            # Install the kernel
            echo -e "${CC_TEXT}Installing the kernel with make install...${CC_RESET}"
            make install
            check_error "Kernel installation failed. Exiting."
            separator
            ;;
        14)
            # Display block device information
            echo -e "${CC_TEXT}Listing block devices with blkid...${CC_RESET}"
            blkid
            check_error "Failed to list block devices. Exiting."

            # Prompt user for disk to use
            while true; do
                echo
                disk_choice=$(execute_if_not_unattended "${CC_TEXT}Please enter the disk you want to use (e.g., sda): ${CC_RESET}" "sda")
                if lsblk -d -n -o NAME | grep -qw "$disk_choice"; then
                    echo
                    echo -e "${CC_TEXT}Disk selected: /dev/$disk_choice${CC_RESET}"
                    break
                else
                    error "Invalid disk selected: $disk_choice. Please try again."
                fi
            done
            separator

            # Append entries to /etc/fstab
            echo -e "${CC_TEXT}Appending entries to /etc/fstab for /dev/${disk_choice}...${CC_RESET}"
            {
                echo
                echo "/dev/${disk_choice}1  /boot   ext4    defaults    0 2"
                echo "/dev/${disk_choice}2  none    swap    sw  0 0"
                echo "/dev/${disk_choice}3  /       ext4    defaults,noatime    0 1"
            } >> /etc/fstab

            check_error "Failed to append entries to /etc/fstab. Exiting."
            separator

            echo -e "${CC_TEXT}fstab entries for /dev/${disk_choice} added successfully.${CC_RESET}"

            # Prompt user to make changes to fstab
            change_conf=$(execute_if_not_unattended "${CC_TEXT}Do you want to make any changes to /etc/fstab? (y/n): ${CC_RESET}" "n")
            if [[ "$change_conf" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /etc/fstab in nano...${CC_RESET}"
                nano /etc/fstab
                check_error "Failed to edit /etc/fstab. Exiting."
            else
                echo -e "${CC_TEXT}No changes made to /etc/fstab.${CC_RESET}"
            fi
            separator
            ;;
        15)
            # Prompt user for the hostname
            while true; do
                user_hostname=$(execute_if_not_unattended "${CC_TEXT}Please enter the hostname for this system: ${CC_RESET}" "thinkpad")
                if [[ -n "$user_hostname" ]]; then
                    break
                else
                    error "Invalid hostname. Please try again."
                fi
            done
            separator

            # Set the hostname
            echo -e "${CC_TEXT}Setting hostname to '$user_hostname'...${CC_RESET}"
            echo "$user_hostname" > /etc/hostname
            check_error "Failed to set hostname. Exiting."
            separator

            # Install netifrc for network configuration
            echo -e "${CC_TEXT}Installing netifrc for network management...${CC_RESET}"
            emerge --noreplace net-misc/netifrc
            check_error "Failed to install netifrc. Exiting."
            separator

            # Detect the actual Ethernet device ID
            echo -e "${CC_TEXT}Detecting Ethernet device ID...${CC_RESET}"
            ethernet_device=$(ip link | awk -F: '/^[0-9]+: e/{print $2; exit}' | tr -d ' ')
            if [ -z "$ethernet_device" ]; then
                error "Failed to detect Ethernet device ID. Exiting."
                exit 1
            fi
            echo -e "${CC_TEXT}Ethernet device detected: $ethernet_device${CC_RESET}"
            separator

            # Write network configuration to /etc/conf.d/net
            echo -e "${CC_TEXT}Configuring network settings for $ethernet_device...${CC_RESET}"
            {
                echo "config_$ethernet_device=\"11.0.0.10/24\""
                echo "routes_$ethernet_device=\"default via 11.0.0.1\""
            } > /etc/conf.d/net

            check_error "Failed to write network configuration to /etc/conf.d/net. Exiting."
            echo -e "${CC_TEXT}Network configuration for $ethernet_device added to /etc/conf.d/net successfully.${CC_RESET}"
            separator

            # Prompt the user if they want to edit /etc/conf.d/net
            edit_net=$(execute_if_not_unattended "${CC_TEXT}Would you like to make any edits to /etc/conf.d/net? (y/n): ${CC_RESET}" "n")
            if [[ "$edit_net" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /etc/conf.d/net in nano...${CC_RESET}"
                nano /etc/conf.d/net
                check_error "Failed to edit /etc/conf.d/net. Exiting."
                echo -e "${CC_TEXT}Finished editing /etc/conf.d/net.${CC_RESET}"
            else
                echo -e "${CC_TEXT}No further edits to /etc/conf.d/net.${CC_RESET}"
            fi
            separator

            # Create symbolic link for the detected Ethernet device
            echo -e "${CC_TEXT}Creating symbolic link for network interface $ethernet_device...${CC_RESET}"
            cd /etc/init.d
            ln -s net.lo net."$ethernet_device"
            check_error "Failed to create symbolic link for $ethernet_device. Exiting."
            separator

            # Add the network interface to the default runlevel
            echo -e "${CC_TEXT}Adding $ethernet_device to the default runlevel...${CC_RESET}"
            rc-update add net."$ethernet_device" default
            check_error "Failed to add $ethernet_device to the default runlevel. Exiting."
            echo -e "${CC_TEXT}Network interface $ethernet_device successfully linked and added to default runlevel.${CC_RESET}"
            separator

            # Prompt the user to edit /etc/hosts
            edit_hosts=$(execute_if_not_unattended "${CC_TEXT}Would you like to edit /etc/hosts? (y/n): ${CC_RESET}" "n")
            if [[ "$edit_hosts" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /etc/hosts in nano...${CC_RESET}"
                nano /etc/hosts
                check_error "Failed to edit /etc/hosts. Exiting"
                separator
            fi 
            ;;
        16)
            # Prompt the user to edit /etc/rc.conf
            edit_rcconf=$(execute_if_not_unattended "${CC_TEXT}Would you like to edit /etc/rc.conf? (y/n): ${CC_RESET}" "n")
            if [[ "$edit_rcconf" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /etc/rc.conf in nano...${CC_RESET}"
                nano /etc/rc.conf
                check_error "Failed to edit /etc/rc.conf. Exiting"
                separator
            fi

            # Replace keymap setting in /etc/conf.d/keymaps
            echo -e "${CC_TEXT}Setting keymap to pt-latin1...${CC_RESET}"
            sed -i 's/^keymap="us"/keymap="pt-latin1"/' /etc/conf.d/keymaps
            check_error "Failed to set keymap. Exiting."

            # Prompt the user to edit /etc/conf.d/keymaps
            edit_keymaps=$(execute_if_not_unattended "${CC_TEXT}Would you like to edit /etc/conf.d/keymaps? (y/n): ${CC_RESET}" "n")
            if [[ "$edit_keymaps" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /etc/conf.d/keymaps in nano...${CC_RESET}"
                nano /etc/conf.d/keymaps
                check_error "Failed to edit /etc/conf.d/keymaps. Exiting"
                separator
            fi

            # Prompt the user to edit /etc/conf.d/hwclock
            edit_hwclock=$(execute_if_not_unattended "${CC_TEXT}Would you like to edit /etc/conf.d/hwclock? (y/n): ${CC_RESET}" "n")
            if [[ "$edit_hwclock" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /etc/conf.d/hwclock in nano...${CC_RESET}"
                nano /etc/conf.d/hwclock
                check_error "Failed to edit /etc/conf.d/hwclock. Exiting"
                separator
            fi
            ;;
        17)
            # Set the root password
            echo -e "${CC_TEXT}Setting root password...${CC_RESET}"
            passwd
            check_error "Failed to set root password. Exiting."
            echo -e "${CC_TEXT}Root password has been set successfully.${CC_RESET}"
            separator
            ;;
        18)
            # Prompt to install and add sysklogd to default runlevel
            install_sysklogd=$(execute_if_not_unattended "${CC_TEXT}Would you like to install app-admin/sysklogd? (y/n): ${CC_RESET}" "n")
            if [[ "$install_sysklogd" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing sysklogd...${CC_RESET}"
                emerge app-admin/sysklogd
                if [ $? -eq 0 ]; then
                    rc-update add sysklogd default
                else
                    error "Failed to install sysklogd. Exiting."
                    exit 1
                fi
                separator
            fi

            # Prompt to install and add cronie to default runlevel
            install_cronie=$(execute_if_not_unattended "${CC_TEXT}Would you like to install sys-process/cronie? (y/n): ${CC_RESET}" "n")
            if [[ "$install_cronie" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing cronie...${CC_RESET}"
                emerge sys-process/cronie
                check_error "Failed to install cronie. Exiting."
                separator
            fi

            # Prompt to install mlocate
            install_mlocate=$(execute_if_not_unattended "${CC_TEXT}Would you like to install sys-apps/mlocate? (y/n): ${CC_RESET}" "n")
            if [[ "$install_mlocate" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing mlocate...${CC_RESET}"
                emerge sys-apps/mlocate
                separator
            fi

            # Add sshd to the default runlevel
            echo -e "${CC_TEXT}Adding sshd to the default runlevel...${CC_RESET}"
            rc-update add sshd default
            check_error "Failed to add sshd to default runlevel. Exiting"
            separator

            # Prompt to install bash-completion
            install_bash_completion=$(execute_if_not_unattended "${CC_TEXT}Would you like to install app-shells/bash-completion? (y/n): ${CC_RESET}" "y")
            if [[ "$install_bash_completion" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing bash-completion...${CC_RESET}"
                emerge app-shells/bash-completion
                check_error "Failed to install bash-completion. Exiting"
                separator
            fi

            # Prompt to install and add chrony to default runlevel
            install_chrony=$(execute_if_not_unattended "${CC_TEXT}Would you like to install net-misc/chrony? (y/n): ${CC_RESET}" "y")
            if [[ "$install_chrony" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing chrony...${CC_RESET}"
                emerge net-misc/chrony
                check_error "Failed to install chrony. Exiting."
                separator
            fi

            # Prompt to install e2fsprogs
            install_e2fsprogs=$(execute_if_not_unattended "${CC_TEXT}Would you like to install sys-fs/e2fsprogs? (y/n): ${CC_RESET}" "y")
            if [[ "$install_e2fsprogs" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing e2fsprogs...${CC_RESET}"
                emerge sys-fs/e2fsprogs
                check_error "Failed to install ee2dsprogs. Exiting."
                separator
            fi

            # Prompt to install io-scheduler-udev-rules
            install_io_scheduler=$(execute_if_not_unattended "${CC_TEXT}Would you like to install sys-block/io-scheduler-udev-rules? (y/n): ${CC_RESET}" "y")
            if [[ "$install_io_scheduler" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing io-scheduler-udev-rules...${CC_RESET}"
                emerge sys-block/io-scheduler-udev-rules
                check_error "Failed to install io-scheduler-udev-rules. Exiting."
                separator
            fi

            # Prompt to install wireless tools (iw and wpa_supplicant)
            install_wireless_tools=$(execute_if_not_unattended "${CC_TEXT}Would you like to install net-wireless/iw and net-wireless/wpa_supplicant? (y/n): ${CC_RESET}" "y")
            if [[ "$install_wireless_tools" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Installing iw and wpa_supplicant...${CC_RESET}"
                emerge net-wireless/iw net-wireless/wpa_supplicant
                check_error "Failed to install wireless. Exiting."
                separator
            fi 
            ;;
        19)
            # Install GRUB to the selected disk
            echo -e "${CC_TEXT}Installing GRUB on /dev/${disk_choice}...${CC_RESET}"
            grub-install /dev/"$disk_choice"
            check_error "Failed to install GRUB on /dev/${disk_choice}. Exiting."
            separator

            # Append settings to /etc/default/grub for graphics mode and OS prober
            echo -e "${CC_TEXT}Configuring GRUB settings in /etc/default/grub...${CC_RESET}"
            {
                echo
                echo "GRUB_GFXMODE=1280x800"
                echo "GRUB_GFXPAYLOAD_LINUX=keep"
                echo "GRUB_DISABLE_OS_PROBER=false"
            } >> /etc/default/grub
            check_error "Failed to update /etc/default/grub. Exiting."
            separator

            # Prompt the user to edit /etc/default/grub
            edit_grub=$(execute_if_not_unattended "${CC_TEXT}Would you like to edit /etc/default/grub in nano? (y/n): ${CC_RESET}" "n")
            if [[ "$edit_grub" =~ ^[Yy]$ ]]; then
                echo -e "${CC_TEXT}Opening /etc/default/grub in nano...${CC_RESET}"
                nano /etc/default/grub
                check_error "Failed to edit /etc/default/grub. Exiting."
                separator
            fi

            # Generate the GRUB configuration
            echo -e "${CC_TEXT}Generating GRUB configuration...${CC_RESET}"
            grub-mkconfig -o /boot/grub/grub.cfg
            check_error "Failed to generate GRUB configuration. Exiting."
            echo -e "${CC_TEXT}GRUB installation and configuration completed successfully.${CC_RESET}"
            separator
            ;;
        20)
            # Prompt the user for a new username
            while true; do
                read -p "$(echo -e "${CC_TEXT}Please enter a username for the new user: ${CC_RESET}")" new_username
                if [[ -n "$new_username" ]]; then
                    echo -e "${CC_TEXT}Username selected: $new_username${CC_RESET}"
                    break
                else
                    error "Invalid username. Please try again."
                fi
            done
            separator

            # Add the new user to the system with specified groups
            echo -e "${CC_TEXT}Creating user $new_username and adding to groups: users, wheel, audio, video, usb...${CC_RESET}"
            useradd -m -G users,wheel,audio,video,usb "$new_username"
            check_error "Failed to add user $new_username. Exiting."
            separator

            # Set password for the new user
            echo -e "${CC_TEXT}Setting password for user $new_username...${CC_RESET}"
            passwd "$new_username"
            check_error "Failed to set password for $new_username. Exiting."
            separator

            # Install sudo
            echo -e "${CC_TEXT}Installing sudo...${CC_RESET}"
            emerge sudo
            check_error "Failed to install sudo. Exiting."
            separator

            # Open visudo to configure sudoers file
            echo -e "${CC_TEXT}Opening visudo to configure sudo permissions...${CC_RESET}"
            visudo
            check_error "Failed to configure sudo permissions. Exiting."
            separator
            ;;
        21)
            # Remove the Stage 3 tarball
            echo -e "${CC_TEXT}Removing the Stage 3 tarball...${CC_RESET}"
            rm /stage3-*.tar.*
            check_error "Failed to remove the Stage 3 tarball. Exiting."
            separator

            # List available news items with eselect
            echo -e "${CC_TEXT}Listing available Gentoo news items...${CC_RESET}"
            eselect news list
            separator

            # Prompt the user to read news items
            echo -e "${CC_TEXT}Reading Gentoo news items...${CC_RESET}"
            eselect news read
            separator 
            ;;
        22)
            # Exit the chroot environment
            echo -e "${CC_TEXT}Exiting the chroot environment...${CC_RESET}"
            separator
            exit
            ;;
        # Add more cases as needed
    esac

    # Delay between steps
    pause
done