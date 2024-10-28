#!/bin/bash

# Automation script by Mountain Interval

# CC_TEXT codes for output
CC_HEADER='\033[1;35;44m'   # Bold Magenta on Blue background - To mark sections or major steps in the script.
CC_TEXT='\033[1;34;40m'     # Bold Blue on Black background - For general text, prompts, and success messages.
CC_ERROR='\033[1;35;40m'     # Bold Magenta on Black background - For error messages.
CC_RESET='\033[0m'          # Reset CC_TEXT - To reset color coding.




# Function to pause the script
pause() {
    sleep 3
}




# Define text separator style
separator() {
    echo -e "${CC_TEXT}│${CC_RESET}"
    echo -e "${CC_TEXT}│${CC_RESET}"
    echo -e "${CC_TEXT}│${CC_RESET}"
    pause
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
    echo -e "${CC_ERROR}Failed to install Gentoo ebuild repository snapshot. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Choosing the right Gentoo profile
echo -e "${CC_TEXT}Listing available Gentoo profiles...${CC_RESET}"
eselect profile list | more

read -p "$(echo -e "${CC_TEXT}Enter the profile number to set: ${CC_RESET}")" profile_number

# Set the chosen profile
eselect profile set "$profile_number"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set the profile. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Prompt user to update the @world set
read -p "$(echo -e "${CC_TEXT}Do you want to update the @world set? (y/n): ${CC_RESET}")" update_world

if [[ "$update_world" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Updating the @world set...${CC_RESET}"
    emerge --ask --verbose --update --deep --changed-use @world
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to update the @world set. Exiting.${CC_RESET}"
        echo
        exit 1
    fi

    # Clean up unnecessary dependencies after the @world update
    echo -e "${CC_TEXT}Cleaning up unnecessary dependencies with emerge --depclean...${CC_RESET}"
    emerge --ask --depclean
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to clean up dependencies. Exiting.${CC_RESET}"
        echo
        exit 1
    fi

    # Run emerge @preserve only if depclean was successful
    echo -e "${CC_TEXT}Checking if any packages need to be rebuilt with emerge @preserve...${CC_RESET}"
    emerge --ask @preserved-rebuild
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to rebuild preserved libraries or packages. Exiting.${CC_RESET}"
        echo
        exit 1
    fi

else
    echo -e "${CC_TEXT}Skipping @world update, dependency cleanup, and rebuild check.${CC_RESET}"
fi
separator





# Setting the system timezone to Europe/Lisbon
echo -e "${CC_TEXT}Setting system timezone to Europe/Lisbon...${CC_RESET}"
ln -sf ../usr/share/zoneinfo/Europe/Lisbon /etc/localtime
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set the system timezone. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Define locales
echo -e "${CC_TEXT}Uncommenting en_US.UTF-8 and pt_PT.UTF-8 in /etc/locale.gen...${CC_RESET}"
sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to uncomment locales in /etc/locale.gen. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Generate locales
echo -e "${CC_TEXT}Generating locales...${CC_RESET}"
locale-gen
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to generate locales. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Listing available locales
echo -e "${CC_TEXT}Listing available locales...${CC_RESET}"
eselect locale list

# Prompting user for the locale number
read -p "$(echo -e "${CC_TEXT}Enter the number corresponding to your desired locale: ${CC_RESET}")" locale_number

# Setting the selected locale
echo -e "${CC_TEXT}Setting the selected locale...${CC_RESET}"
eselect locale set "$locale_number"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set the locale. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Updating environment and sourcing profile
echo -e "${CC_TEXT}Updating environment and sourcing /etc/profile...${CC_RESET}"
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to update environment and source profile. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# # Accepting licenses for linux-firmware
# echo -e "${CC_TEXT}Updating /etc/portage/package.license to accept licenses for linux-firmware and intel-microcode...${CC_RESET}"

# # Ensure the directory for package.license exists
# mkdir -p /etc/portage

# # Append the required license information to package.license
# cat <<EOL >> /etc/portage/package.license
# # Accept the license for linux-firmware
# sys-kernel/linux-firmware linux-fw-redistributable

# # Accept any license that permits redistribution for linux-firmware
# sys-kernel/linux-firmware @BINARY-REDISTRIBUTABLE

# # Intel Microcode
# sys-firmware/intel-microcode intel-ucode
# EOL

# if [ $? -ne 0 ]; then
#     echo
#     echo -e "${CC_ERROR}Failed to update /etc/portage/package.license. Exiting.${CC_RESET}"
#     echo
#     exit 1
# fi
# separator




# Installing linux-firmware and intel-microcode
echo -e "${CC_TEXT}Installing linux-firmware and intel-microcode...${CC_RESET}"
emerge --ask sys-kernel/linux-firmware sys-firmware/intel-microcode
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install linux-firmware or intel-microcode. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Installing installkernel
echo -e "${CC_TEXT}Installing installkernel...${CC_RESET}"
emerge --ask sys-kernel/installkernel
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install installkernel. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Creating /etc/portage/package.use/installkernel and setting USE flag for installkernel
echo -e "${CC_TEXT}Creating /etc/portage/package.use/installkernel and setting USE flag for installkernel...${CC_RESET}"

# Ensure the directory for package.use exists
mkdir -p /etc/portage/package.use

# Write the required entry to the file
echo "sys-kernel/installkernel grub dracut" > /etc/portage/package.use/installkernel

if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to create /etc/portage/package.use/installkernel. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Prompting user for kernel installation option
echo -e "${CC_TEXT}Would you like to install the kernel from source or use a precompiled image?${CC_RESET}"
echo -e "${CC_TEXT}1) Build a kernel with Gentoo patches from source (sys-kernel/gentoo-kernel)${CC_RESET}"
echo -e "${CC_TEXT}2) Install precompiled kernel images (sys-kernel/gentoo-kernel-bin)${CC_RESET}"

# User input for selection
read -p "$(echo -e "${CC_TEXT}Enter your choice (1 or 2): ${CC_RESET}")" kernel_choice

if [[ "$kernel_choice" == "1" ]]; then
    # Installing gentoo-kernel from source
    echo -e "${CC_TEXT}Installing gentoo-kernel from source...${CC_RESET}"
    emerge --ask sys-kernel/gentoo-kernel
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to install gentoo-kernel. Exiting.${CC_RESET}"
        echo
        exit 1
    fi

elif [[ "$kernel_choice" == "2" ]]; then
    # Installing gentoo-kernel-bin (precompiled)
    echo -e "${CC_TEXT}Installing gentoo-kernel-bin (precompiled kernel image)...${CC_RESET}"
    emerge --ask sys-kernel/gentoo-kernel-bin
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to install gentoo-kernel-bin. Exiting.${CC_RESET}"
        echo
        exit 1
    fi

else
    echo -e "${CC_ERROR}Invalid choice. Please enter 1 or 2. Exiting.${CC_RESET}"
    exit 1
fi
separator




# Cleaning up unnecessary dependencies
echo -e "${CC_TEXT}Cleaning up unnecessary dependencies with emerge --depclean...${CC_RESET}"
emerge --ask --depclean
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to clean up dependencies. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator
