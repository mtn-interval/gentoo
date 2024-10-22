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




# Script header
echo -e "${CC_HEADER}────── Install System Core  v1.00 ──────${CC_RESET}"
echo
pause




# Set keyboard layout to Portuguese (Latin-1)
echo -e "${CC_TEXT}Setting keyboard layout to pt-latin1...${CC_RESET}"
loadkeys pt-latin1
separator




# List available disks
while true; do
    echo -e "${CC_TEXT}Available Disks:${CC_RESET}"
    echo
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    echo

    # Prompt the user to select a disk
    read -p "$(echo -e "${CC_TEXT}Please enter the disk you want to use (e.g., sda): ${CC_RESET}")" disk

    # Check if the selected disk is valid
    if lsblk -d -n -o NAME | grep -qw "$disk"; then
        echo
        echo -e "${CC_TEXT}Valid disk selected: /dev/$disk${CC_RESET}"
        break  # Break the loop if the disk is valid
    else
        echo
        echo -e "${CC_TEXT}Invalid disk selected: $disk. Please try again.${CC_RESET}"
        echo
    fi
done




# Confirm the choice and warn about data erasure
echo
echo -e "${CC_TEXT}Warning: All data on /dev/$disk will be erased!${CC_RESET}"            
while true; do
    read -p "$(echo -e "${CC_TEXT}Are you sure you want to continue? (y/n): ${CC_RESET}")" confirm
    case $confirm in
        y|Y)
            break  # Break the loop and continue to the next step
            ;;
        n|N)
            echo
            echo -e "${CC_ERROR}Exiting without making any changes.${CC_RESET}"
            echo
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
        if [ $? -ne 0 ]; then
            echo
            echo -e "${CC_ERROR}Failed to wipe /dev/$partition. Exiting.${CC_RESET}"
            echo
            exit 1
        fi
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
echo +1G	# Assign 1GB to the boot partition
echo a      # Make partition bootable
echo n      # Add a new partition
echo p      # Primary partition
echo 2      # Partition number 2
echo        # Default
echo +4G	# Assign 4GB to the swap partition
echo t      # Define swap partition type
echo 2
echo 82
echo n      # Add a new partition
echo p      # Primary partition
echo 3      # Partition number 3
echo        # Default
echo        # Default - last sector (use full disk)
echo p 		# Show list of partitions
echo w      # Write changes
) | fdisk --color=never /dev/$disk

if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Partitioning failed on /dev/$disk. Exiting.${CC_RESET}"
    echo
    exit 1
fi

echo
echo -e "${CC_TEXT}Partitioning complete on /dev/$disk.${CC_RESET}"
separator




# Formatting the partitions
echo -e "${CC_TEXT}Formatting /dev/${disk}1 as XFS (boot partition)...${CC_RESET}"
mkfs.xfs /dev/${disk}1
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}PFailed to format /dev/${disk}1. Exiting.${CC_RESET}"
    echo
    exit 1
fi

echo -e "${CC_TEXT}Formatting /dev/${disk}3 as XFS (root partition)...${CC_RESET}"
mkfs.xfs /dev/${disk}3
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to format /dev/${disk}3. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Activating the swap partition
echo -e "${CC_TEXT}Setting up and activating swap on /dev/${disk}2...${CC_RESET}"
mkswap /dev/${disk}2
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to set up swap on /dev/${disk}2. Exiting.${CC_RESET}"
    echo
    exit 1
fi

swapon /dev/${disk}2
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to activate swap on /dev/${disk}2. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Mounting partitions
echo -e "${CC_TEXT}Mounting root partition (/dev/${disk}3) to /mnt/gentoo...${CC_RESET}"
mkdir -p /mnt/gentoo
mount /dev/${disk}3 /mnt/gentoo
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to mount /dev/${disk}3. Exiting.${CC_RESET}"
    echo
    exit 1
fi

echo -e "${CC_TEXT}Mounting boot partition (/dev/${disk}1) to /mnt/gentoo/boot...${CC_RESET}"
mkdir -p /mnt/gentoo/boot
mount /dev/${disk}1 /mnt/gentoo/boot
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to mount /dev/${disk}1. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Synchronizing the system clock
echo -e "${CC_TEXT}Synchronizing the system clock using chronyd...${CC_RESET}"
chronyd -q
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to synchronize the system clock. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Downloading the Stage 3 tarball
echo -e "${CC_TEXT}Navigating to Gentoo mirrors to download the latest Stage 3 tarball...${CC_RESET}"
cd /mnt/gentoo
echo -e "${CC_TEXT}Launching links browser. Please navigate to the latest Stage 3 release, press 'd' to download.${CC_RESET}"
pause
links https://www.gentoo.org/downloads/mirrors/

echo -e "${CC_TEXT}Exiting links browser. Proceeding with the installation...${CC_RESET}"
separator




# Unpacking the Stage 3 tarball
echo -e "${CC_TEXT}Unpacking the Stage 3 tarball...${CC_RESET}"
cd /mnt/gentoo
tar xpf stage3*
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to unpack the Stage 3 tarball. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator





# Configuring compile options in make.conf
echo -e "${CC_TEXT}Configuring compile options in /mnt/gentoo/etc/portage/make.conf...${CC_RESET}"

# Replace the COMMON_FLAGS line
sed -i 's/^COMMON_FLAGS=.*/COMMON_FLAGS="-march=native -O2 -pipe"/' /mnt/gentoo/etc/portage/make.conf

# Append additional options to the file
cat <<EOL >> /mnt/gentoo/etc/portage/make.conf
MAKEOPTS="-j1 -l2"
CHOST="x86_64-pc-linux-gnu"
GENTOO_MIRRORS="https://ftp.rnl.tecnico.ulisboa.pt/pub/gentoo/gentoo-distfiles/"
VIDEO_CARDS="intel"
INPUT_DEVICES="libinput"
CPU_FLAGS_X86="mmx mmxext sse sse2 sse3 ssse3"
ACCEPT_LICENSE="*"
EOL

if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to configure /mnt/gentoo/etc/portage/make.conf. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Prompt user to make changes to make.conf
read -p "$(echo -e "${CC_TEXT}Do you want to make any changes to /mnt/gentoo/etc/portage/make.conf? (y/n): ${CC_RESET}")" change_conf

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
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to copy DNS information. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator




# Copy necessary install scripts to the new system
echo -e "${CC_TEXT}Copying installation scripts to /mnt/gentoo...${CC_RESET}"
cp *--*.sh /mnt/gentoo/
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to copy installation scripts. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator

# Change root into the new environment and run the chroot script
echo -e "${CC_TEXT}Entering the chroot environment and executing 03--chroot.sh...${CC_RESET}"
arch-chroot /mnt/gentoo /mnt/gentoo/03--chroot.sh
if [ $? -ne 0 ]; then
    echo
    echo -e "${CC_ERROR}Failed to chroot into the new environment. Exiting.${CC_RESET}"
    echo
    exit 1
fi
separator





