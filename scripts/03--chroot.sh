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
echo -e "${CC_HEADER}────── Change root into the new system  v0.05 ──────${CC_RESET}"
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




# Sync the Portage tree and capture the output while displaying it
echo -e "${CC_TEXT}Synchronizing the Portage tree with emerge --sync...${CC_RESET}"
sync_output=$(emerge --sync 2>&1 | tee /dev/tty)
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to synchronize the Portage tree. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Check if there's an update available for Portage
if echo "$sync_output" | grep -iq "an update to portage is available"; then
    # Prompt the user to update Portage
    read -p "$(echo -e "${CC_TEXT}An update to Portage is available. Would you like to update it now? (y/n): ${CC_RESET}")" update_portage
    if [[ "$update_portage" =~ ^[Yy]$ ]]; then
        echo -e "${CC_TEXT}Updating Portage...${CC_RESET}"
        emerge --oneshot sys-apps/portage
        if [ $? -ne 0 ]; then
            echo
            echo -e "${CC_ERROR}Failed to update Portage. Exiting.${CC_RESET}"
            echo
            exit 1
        fi
        echo -e "${CC_TEXT}Portage updated successfully.${CC_RESET}"
    else
        echo -e "${CC_TEXT}Portage update skipped by user.${CC_RESET}"
    fi
else
    echo -e "${CC_TEXT}No Portage update needed.${CC_RESET}"
fi
separator




# Choosing the right Gentoo profile
echo -e "${CC_TEXT}Listing available Gentoo profiles...${CC_RESET}"
eselect profile list | more
echo
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
    emerge --verbose --update --deep --changed-use @world
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to update the @world set. Exiting.${CC_RESET}"
        echo
        exit 1
    fi

    # Clean up unnecessary dependencies after the @world update
    echo -e "${CC_TEXT}Cleaning up unnecessary dependencies with emerge --depclean...${CC_RESET}"
    emerge --depclean
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to clean up dependencies. Exiting.${CC_RESET}"
        echo
        exit 1
    fi

    # Run emerge @preserve only if depclean was successful
    echo -e "${CC_TEXT}Checking if any packages need to be rebuilt with emerge @preserve...${CC_RESET}"
    emerge @preserved-rebuild
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




# Detect if the Stage 3 tarball filename in root contains "musl"
stage3_tarball=$(ls /stage3-*.tar.* 2>/dev/null | head -n 1)  # Detect the tarball file in the root directory

if [[ -z "$stage3_tarball" ]]; then
    echo -e "${CC_ERROR}Stage 3 tarball not found in the root directory. Exiting.${CC_RESET}"
    exit 1
fi

if echo "$stage3_tarball" | grep -iq "musl"; then
    echo -e "${CC_TEXT}Detected musl Stage 3 tarball...${CC_RESET}"
    echo

    # Install timezone data
    echo -e "${CC_TEXT}Installing timezone data package...${CC_RESET}"
    emerge sys-libs/timezone-data
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to install timezone data. Exiting.${CC_RESET}"
        echo
        exit 1
    fi
    separator

    # Set timezone to Europe/Lisbon
    echo -e "${CC_TEXT}Setting timezone to Europe/Lisbon...${CC_RESET}"
    printf 'TZ="%s"' "$(cat /usr/share/zoneinfo/Europe/Lisbon | tail -n 1)" | tee /etc/env.d/00local
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to set timezone. Exiting.${CC_RESET}"
        echo
        exit 1
    fi
    separator

    # Update environment and source profile
    echo -e "${CC_TEXT}Updating environment and sourcing profile...${CC_RESET}"
    env-update && source /etc/profile
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to update environment. Exiting.${CC_RESET}"
        echo
        exit 1
    fi
    echo
    date
    separator

    # Uninstall timezone data package
    echo -e "${CC_TEXT}Removing timezone data package...${CC_RESET}"
    emerge --unmerge sys-libs/timezone-data
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to remove timezone data package. Exiting.${CC_RESET}"
        echo
        exit 1
    fi
    separator
else
    echo -e "${CC_TEXT}No musl Stage 3 tarball detected...${CC_RESET}"
    echo
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
fi




# Prompt the user if they want to install linux-firmware
read -p "$(echo -e "${CC_TEXT}Would you like to install linux-firmware? (y/n): ${CC_RESET}")" install_linux_firmware
if [[ "$install_linux_firmware" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing linux-firmware...${CC_RESET}"
    emerge sys-kernel/linux-firmware
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to install linux-firmware. Exiting.${CC_RESET}"
        echo
        exit 1
    fi
    echo -e "${CC_TEXT}linux-firmware installed successfully.${CC_RESET}"
else
    echo -e "${CC_TEXT}Skipping installation of linux-firmware.${CC_RESET}"
fi
separator

# Prompt the user if they want to install intel-microcode
read -p "$(echo -e "${CC_TEXT}Would you like to install intel-microcode? (y/n): ${CC_RESET}")" install_intel_microcode
if [[ "$install_intel_microcode" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing intel-microcode...${CC_RESET}"
    emerge sys-firmware/intel-microcode
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to install intel-microcode. Exiting.${CC_RESET}"
        echo
        exit 1
    fi
    echo -e "${CC_TEXT}intel-microcode installed successfully.${CC_RESET}"
else
    echo -e "${CC_TEXT}Skipping installation of intel-microcode.${CC_RESET}"
fi
separator




# Configure installkernel to use GRUB
echo -e "${CC_TEXT}Configuring installkernel to use GRUB...${CC_RESET}"
echo "sys-kernel/installkernel grub" > /etc/portage/package.use/installkernel
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to configure installkernel for GRUB. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Install the installkernel package
echo -e "${CC_TEXT}Installing sys-kernel/installkernel package...${CC_RESET}"
emerge sys-kernel/installkernel
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install sys-kernel/installkernel. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Install Gentoo kernel sources
echo -e "${CC_TEXT}Installing Gentoo kernel sources...${CC_RESET}"
emerge sys-kernel/gentoo-sources
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install gentoo-sources. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# List available kernels
echo -e "${CC_TEXT}Listing available kernel versions...${CC_RESET}"
eselect kernel list
echo
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to list kernel versions. Exiting.${CC_RESET}"
    echo
    exit 1
fi

# Prompt the user to select a kernel
while true; do
    read -p "$(echo -e "${CC_TEXT}Please enter the number of the kernel version you want to set: ${CC_RESET}")" kernel_number
    if [[ "$kernel_number" =~ ^[0-9]+$ ]]; then
        echo -e "${CC_TEXT}Setting kernel version $kernel_number...${CC_RESET}"
        eselect kernel set "$kernel_number"
        if [ $? -eq 0 ]; then
            echo
            echo -e "${CC_TEXT}Kernel version $kernel_number has been set.${CC_RESET}"
            break
        else
            echo
            echo -e "${CC_ERROR}Failed to set kernel version $kernel_number. Please try again.${CC_RESET}"
            echo
        fi
    else
        echo
        echo -e "${CC_ERROR}Invalid input. Please enter a valid number.${CC_RESET}"
        echo
    fi
done
separator

# Verify the kernel symlink
echo -e "${CC_TEXT}Setting the /usr/src/linux symlink...${CC_RESET}"
ls -l /usr/src/linux
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set /usr/src/linux symlink. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Install pciutils package
echo -e "${CC_TEXT}Installing pciutils package for lspci command...${CC_RESET}"
emerge sys-apps/pciutils
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install pciutils. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Create a directory for system information and collect hardware details
echo -e "${CC_TEXT}Creating directory ~/system_info and collecting system information...${CC_RESET}"
mkdir -p ~/system_info
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to create ~/system_info directory. Exiting.${CC_RESET}"
    echo
    exit 1
fi

# Collect system information
lscpu > ~/system_info/lscpu_output.txt
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to collect CPU information. Exiting.${CC_RESET}"
    echo
    exit 1
fi

lspci > ~/system_info/lspci_output.txt
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to collect PCI device information. Exiting.${CC_RESET}"
    echo
    exit 1
fi

lsmod > ~/system_info/lsmod_output.txt
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to collect loaded module information. Exiting.${CC_RESET}"
    echo
    exit 1
fi
echo -e "${CC_TEXT}System information has been saved to ~/system_info directory.${CC_RESET}"
separator




# Prompt the user if they want to install dev-util/pahole
read -p "$(echo -e "${CC_TEXT}Would you like to install dev-util/pahole? (y/n): ${CC_RESET}")" install_pahole
if [[ "$install_pahole" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing dev-util/pahole...${CC_RESET}"
    emerge dev-util/pahole
    if [ $? -ne 0 ]; then
        echo
        echo -e "${CC_ERROR}Failed to install dev-util/pahole. Exiting.${CC_RESET}"
        echo
        exit 1
    fi
    echo -e "${CC_TEXT}dev-util/pahole installed successfully.${CC_RESET}"
else
    echo -e "${CC_TEXT}Skipping installation of dev-util/pahole.${CC_RESET}"
fi
separator




# Generate a minimal kernel configuration based on loaded modules
echo -e "${CC_TEXT}Generating a minimal kernel configuration based on currently loaded modules with make localmodconfig...${CC_RESET}"
cd /usr/src/linux
make localmodconfig
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to generate minimal kernel configuration. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Open the kernel configuration menu for customization
echo -e "${CC_TEXT}Opening kernel configuration menu with make nconfig...${CC_RESET}"
make nconfig
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to open kernel configuration menu. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Build the kernel
echo -e "${CC_TEXT}Building the kernel with make...${CC_RESET}"
make
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Kernel build failed. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Install kernel modules
echo -e "${CC_TEXT}Installing kernel modules with make modules_install...${CC_RESET}"
make modules_install
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install kernel modules. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Install the kernel
echo -e "${CC_TEXT}Installing the kernel with make install...${CC_RESET}"
make install
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Kernel installation failed. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Display block device information
echo -e "${CC_TEXT}Listing block devices with blkid...${CC_RESET}"
blkid
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to list block devices. Exiting.${CC_RESET}"
    echo
    exit 1
fi

# Prompt user for disk to use
while true; do
    echo
    read -p "$(echo -e "${CC_TEXT}Please enter the disk you want to use (e.g., sda): ${CC_RESET}")" disk_choice
    if lsblk -d -n -o NAME | grep -qw "$disk_choice"; then
        echo
        echo -e "${CC_TEXT}Disk selected: /dev/$disk_choice${CC_RESET}"
        break
    else
        echo
        echo -e "${CC_ERROR}Invalid disk selected: $disk_choice. Please try again.${CC_RESET}"
        echo
    fi
done
separator

# Append entries to /etc/fstab
echo -e "${CC_TEXT}Appending entries to /etc/fstab for /dev/${disk_choice}...${CC_RESET}"
{
    echo
    echo "/dev/${disk_choice}1      /boot       ext4        defaults    0 2"
    echo "/dev/${disk_choice}2      none        swap        sw      0 0"
    echo "/dev/${disk_choice}3      /       ext4        defaults,noatime    0 1"
} >> /etc/fstab

if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to append entries to /etc/fstab. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

echo -e "${CC_TEXT}fstab entries for /dev/${disk_choice} added successfully.${CC_RESET}"




# Prompt user to make changes to fstab
read -p "$(echo -e "${CC_TEXT}Do you want to make any changes to /etc/fstab? (y/n): ${CC_RESET}")" change_conf

if [[ "$change_conf" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Opening /etc/fstab in nano...${CC_RESET}"
    nano /etc/fstab
else
    echo -e "${CC_TEXT}No changes made to /etc/fstab.${CC_RESET}"
fi
separator




# Prompt user for the hostname
while true; do
    read -p "$(echo -e "${CC_TEXT}Please enter the hostname for this system: ${CC_RESET}")" user_hostname
    if [[ -n "$user_hostname" ]]; then
        break
    else
        echo
        echo -e "${CC_ERROR}Invalid hostname. Please try again.${CC_RESET}"
        echo
    fi
done
separator

# Set the hostname
echo -e "${CC_TEXT}Setting hostname to '$user_hostname'...${CC_RESET}"
echo "$user_hostname" > /etc/hostname
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set hostname. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Install netifrc for network configuration
echo -e "${CC_TEXT}Installing netifrc for network management...${CC_RESET}"
emerge --noreplace net-misc/netifrc
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install netifrc. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Detect the actual Ethernet device ID
echo -e "${CC_TEXT}Detecting Ethernet device ID...${CC_RESET}"
ethernet_device=$(ip link | awk -F: '/^[0-9]+: e/{print $2; exit}' | tr -d ' ')
if [ -z "$ethernet_device" ]; then
    echo
    echo -e "${CC_ERROR}Failed to detect Ethernet device ID. Exiting.${CC_RESET}"
    echo
    exit 1
fi
echo -e "${CC_TEXT}Ethernet device detected: $ethernet_device${CC_RESET}"
separator

# Write network configuration to /etc/conf.d/net
echo -e "${CC_TEXT}Configuring network settings for $ethernet_device...${CC_RESET}"
{
    echo "config_$ethernet_device=\"10.0.0.10/24\""
    echo "routes_$ethernet_device=\"default via 10.0.0.1\""
} > /etc/conf.d/net

if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to write network configuration to /etc/conf.d/net. Exiting.${CC_RESET}"
    echo
    exit 1
fi
echo -e "${CC_TEXT}Network configuration for $ethernet_device added to /etc/conf.d/net successfully.${CC_RESET}"
separator




# Create symbolic link for the detected Ethernet device
echo -e "${CC_TEXT}Creating symbolic link for network interface $ethernet_device...${CC_RESET}"
cd /etc/init.d
ln -s net.lo net."$ethernet_device"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to create symbolic link for $ethernet_device. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Add the network interface to the default runlevel
echo -e "${CC_TEXT}Adding $ethernet_device to the default runlevel...${CC_RESET}"
rc-update add net."$ethernet_device" default
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to add $ethernet_device to the default runlevel. Exiting.${CC_RESET}"
    echo
    exit 1
fi
echo -e "${CC_TEXT}Network interface $ethernet_device successfully linked and added to default runlevel.${CC_RESET}"
separator




# Prompt the user to edit /etc/hosts
read -p "$(echo -e "${CC_TEXT}Would you like to edit /etc/hosts? (y/n): ${CC_RESET}")" edit_hosts
if [[ "$edit_hosts" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Opening /etc/hosts in nano...${CC_RESET}"
    nano /etc/hosts
    separator
fi

# Prompt the user to edit /etc/rc.conf
read -p "$(echo -e "${CC_TEXT}Would you like to edit /etc/rc.conf? (y/n): ${CC_RESET}")" edit_rcconf
if [[ "$edit_rcconf" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Opening /etc/rc.conf in nano...${CC_RESET}"
    nano /etc/rc.conf
    separator
fi

# Prompt the user to edit /etc/conf.d/keymaps
read -p "$(echo -e "${CC_TEXT}Would you like to edit /etc/conf.d/keymaps? (y/n): ${CC_RESET}")" edit_keymaps
if [[ "$edit_keymaps" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Opening /etc/conf.d/keymaps in nano...${CC_RESET}"
    nano /etc/conf.d/keymaps
    separator
fi

# Prompt the user to edit /etc/conf.d/hwclock
read -p "$(echo -e "${CC_TEXT}Would you like to edit /etc/conf.d/hwclock? (y/n): ${CC_RESET}")" edit_hwclock
if [[ "$edit_hwclock" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Opening /etc/conf.d/hwclock in nano...${CC_RESET}"
    nano /etc/conf.d/hwclock
    separator
fi

# Set the root password
echo -e "${CC_TEXT}Setting root password...${CC_RESET}"
passwd
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set root password. Exiting.${CC_RESET}"
    echo
    exit 1
fi
echo -e "${CC_TEXT}Root password has been set successfully.${CC_RESET}"
separator




# Prompt to install and add sysklogd to default runlevel
read -p "$(echo -e "${CC_TEXT}Would you like to install app-admin/sysklogd? (y/n): ${CC_RESET}")" install_sysklogd
if [[ "$install_sysklogd" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing sysklogd...${CC_RESET}"
    emerge app-admin/sysklogd
    if [ $? -eq 0 ]; then
        rc-update add sysklogd default
    else
        echo -e "${CC_ERROR}Failed to install sysklogd.${CC_RESET}"
    fi
    separator
fi

# Prompt to install and add cronie to default runlevel
read -p "$(echo -e "${CC_TEXT}Would you like to install sys-process/cronie? (y/n): ${CC_RESET}")" install_cronie
if [[ "$install_cronie" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing cronie...${CC_RESET}"
    emerge sys-process/cronie
    if [ $? -eq 0 ]; then
        rc-update add cronie default
    else
        echo -e "${CC_ERROR}Failed to install cronie.${CC_RESET}"
    fi
    separator
fi

# Prompt to install mlocate
read -p "$(echo -e "${CC_TEXT}Would you like to install sys-apps/mlocate? (y/n): ${CC_RESET}")" install_mlocate
if [[ "$install_mlocate" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing mlocate...${CC_RESET}"
    emerge sys-apps/mlocate
    separator
fi

# Add sshd to the default runlevel
echo -e "${CC_TEXT}Adding sshd to the default runlevel...${CC_RESET}"
rc-update add sshd default
separator

# Prompt to install bash-completion
read -p "$(echo -e "${CC_TEXT}Would you like to install app-shells/bash-completion? (y/n): ${CC_RESET}")" install_bash_completion
if [[ "$install_bash_completion" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing bash-completion...${CC_RESET}"
    emerge app-shells/bash-completion
    separator
fi

# Prompt to install and add chrony to default runlevel
read -p "$(echo -e "${CC_TEXT}Would you like to install net-misc/chrony? (y/n): ${CC_RESET}")" install_chrony
if [[ "$install_chrony" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing chrony...${CC_RESET}"
    emerge net-misc/chrony
    if [ $? -eq 0 ]; then
        rc-update add chronyd default
    else
        echo -e "${CC_ERROR}Failed to install chrony.${CC_RESET}"
    fi
    separator
fi

# Prompt to install e2fsprogs
read -p "$(echo -e "${CC_TEXT}Would you like to install sys-fs/e2fsprogs? (y/n): ${CC_RESET}")" install_e2fsprogs
if [[ "$install_e2fsprogs" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing e2fsprogs...${CC_RESET}"
    emerge sys-fs/e2fsprogs
    separator
fi

# Prompt to install io-scheduler-udev-rules
read -p "$(echo -e "${CC_TEXT}Would you like to install sys-block/io-scheduler-udev-rules? (y/n): ${CC_RESET}")" install_io_scheduler
if [[ "$install_io_scheduler" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing io-scheduler-udev-rules...${CC_RESET}"
    emerge sys-block/io-scheduler-udev-rules
    separator
fi

# Prompt to install wireless tools (iw and wpa_supplicant)
read -p "$(echo -e "${CC_TEXT}Would you like to install net-wireless/iw and net-wireless/wpa_supplicant? (y/n): ${CC_RESET}")" install_wireless_tools
if [[ "$install_wireless_tools" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Installing iw and wpa_supplicant...${CC_RESET}"
    emerge net-wireless/iw net-wireless/wpa_supplicant
    separator
fi




# Install GRUB to the selected disk
echo -e "${CC_TEXT}Installing GRUB on /dev/${disk_choice}...${CC_RESET}"
grub-install /dev/"$disk_choice"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install GRUB on /dev/${disk_choice}. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Append settings to /etc/default/grub for graphics mode and OS prober
echo -e "${CC_TEXT}Configuring GRUB settings in /etc/default/grub...${CC_RESET}"
{
    echo
    echo "GRUB_GFXMODE=1280x800"
    echo "GRUB_GFXPAYLOAD_LINUX=keep"
    echo "GRUB_DISABLE_OS_PROBER=false"
} >> /etc/default/grub
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to update /etc/default/grub. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Prompt the user to edit /etc/default/grub
read -p "$(echo -e "${CC_TEXT}Would you like to edit /etc/default/grub in nano? (y/n): ${CC_RESET}")" edit_grub
if [[ "$edit_grub" =~ ^[Yy]$ ]]; then
    echo -e "${CC_TEXT}Opening /etc/default/grub in nano...${CC_RESET}"
    nano /etc/default/grub
    separator
fi

# Generate the GRUB configuration
echo -e "${CC_TEXT}Generating GRUB configuration...${CC_RESET}"
grub-mkconfig -o /boot/grub/grub.cfg
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to generate GRUB configuration. Exiting.${CC_RESET}"
    echo
    exit 1
fi
echo -e "${CC_TEXT}GRUB installation and configuration completed successfully.${CC_RESET}"
separator




# Prompt the user for a new username
while true; do
    read -p "$(echo -e "${CC_TEXT}Please enter a username for the new user: ${CC_RESET}")" new_username
    if [[ -n "$new_username" ]]; then
        echo -e "${CC_TEXT}Username selected: $new_username${CC_RESET}"
        break
    else
        echo -e "${CC_ERROR}Invalid username. Please try again.${CC_RESET}"
    fi
done
separator

# Add the new user to the system with specified groups
echo -e "${CC_TEXT}Creating user $new_username and adding to groups: users, wheel, audio, video, usb...${CC_RESET}"
useradd -m -G users,wheel,audio,video,usb "$new_username"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to add user $new_username. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Set password for the new user
echo -e "${CC_TEXT}Setting password for user $new_username...${CC_RESET}"
passwd "$new_username"
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set password for $new_username. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Install sudo
echo -e "${CC_TEXT}Installing sudo...${CC_RESET}"
emerge sudo
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to install sudo. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Open visudo to configure sudoers file
echo -e "${CC_TEXT}Opening visudo to configure sudo permissions...${CC_RESET}"
visudo
separator




# Remove the Stage 3 tarball
echo -e "${CC_TEXT}Removing the Stage 3 tarball...${CC_RESET}"
rm /stage3-*.tar.*
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to remove the Stage 3 tarball. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# List available news items with eselect
echo -e "${CC_TEXT}Listing available Gentoo news items...${CC_RESET}"
eselect news list
separator

# Prompt the user to read news items
echo -e "${CC_TEXT}Reading Gentoo news items...${CC_RESET}"
eselect news read
separator




# Prompt the user to reboot or end the script
while true; do
    read -p "$(echo -e "${CC_TEXT}Would you like to reboot the system now? (y/n): ${CC_RESET}")" reboot_choice
    case $reboot_choice in
        [Yy]* )

            # Exit the chroot environment
            echo -e "${CC_TEXT}Exiting the chroot environment...${CC_RESET}"
            exit
            cd
            separator

            # Unmount all filesystems from /mnt/gentoo
            echo -e "${CC_TEXT}Unmounting all filesystems from /mnt/gentoo...${CC_RESET}"
            umount -R /mnt/gentoo
            if [ $? -ne 0 ]; then
                echo
                echo -e "${CC_ERROR}Failed to unmount /mnt/gentoo. Exiting.${CC_RESET}"
                echo
                exit 1
            fi
            separator

            echo -e "${CC_TEXT}Rebooting system...${CC_RESET}"
            reboot
            break
            ;;
        [Nn]* )
            echo -e "${CC_TEXT}Exiting script. System not rebooted.${CC_RESET}"
            break
            ;;
        * )
            echo -e "${CC_ERROR}Invalid choice. Please enter 'y' or 'n'.${CC_RESET}"
            ;;
    esac
done