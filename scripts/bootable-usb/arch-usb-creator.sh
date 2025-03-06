#!/bin/bash

# Arch Linux Bootable USB Creator
# This script helps create a bootable USB drive for Arch Linux installation
# and includes the Mango Linux Configuration repository content

# Colors for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# MIT Mirror URL
MIT_MIRROR="https://mirrors.mit.edu/archlinux/iso/"

# Hardcoded Arch version - can be easily changed here
ARCH_VERSION="2025.01.01"

# Function to check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run this script with sudo or as root${NC}"
        exit 1
    fi
}

# Function to check if required tools are installed
check_dependencies() {
    local deps=("wget" "dd" "grep" "rsync")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}The following dependencies are missing:${NC}"
        printf "  %s\n" "${missing[@]}"
        echo -e "${YELLOW}Please install them using your package manager and try again.${NC}"
        exit 1
    fi
}

# Function to list available USB drives
list_usb_drives() {
    echo -e "${YELLOW}Available USB Drives:${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${BLUE}NAME       SIZE   TYPE   MOUNTPOINT   MODEL${NC}"
    echo -e "${BLUE}--------------------------------------------------${NC}"
    
    # List removable drives and filter out primary disk
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,RM | grep -E "1$|disk.*1$|part.*1$" | grep -v $(mount | grep "on / " | cut -d' ' -f1 | cut -d'/' -f3 | cut -c 1-3) | sort
    
    # Alternative: show all disks except the system disk
    if ! lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,RM | grep -q "1$"; then
        echo -e "${YELLOW}No removable drives detected. Listing all disks except system disk:${NC}"
        system_disk=$(mount | grep "on / " | cut -d' ' -f1 | cut -d'/' -f3 | cut -c 1-3)
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL | grep "disk" | grep -v "$system_disk" | sort
    fi
    
    echo -e "${BLUE}--------------------------------------------------${NC}"
    echo -e "${YELLOW}Note: You need to specify the full path like /dev/sdb${NC}"
}

# Function to download Arch Linux ISO from MIT mirror
download_iso() {
    local version="$ARCH_VERSION"
    local iso_url="${MIT_MIRROR}${version}/archlinux-${version}-x86_64.iso"
    local iso_filename="archlinux-${version}-x86_64.iso"

    echo -e "${GREEN}Downloading Arch Linux ${version} from MIT mirror...${NC}"
    echo -e "${YELLOW}URL: ${iso_url}${NC}"
    
    # Download with wget, showing progress
    wget --progress=bar:force -O "${iso_filename}" "${iso_url}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Download complete: ${iso_filename}${NC}"
        
        # Verify download by checking file size
        local file_size=$(stat -c %s "${iso_filename}")
        if [ "$file_size" -lt 700000000 ]; then  # ISO should be at least ~700MB
            echo -e "${RED}Warning: Downloaded file seems too small (${file_size} bytes).${NC}"
            echo -e "${YELLOW}The download might be incomplete or corrupted.${NC}"
            read -p "Do you want to continue anyway? (yes/no): " continue_anyway
            if [[ "$continue_anyway" != "yes" ]]; then
                echo -e "${RED}Operation cancelled.${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${RED}Download failed. Please check your internet connection.${NC}"
        exit 1
    fi
}

# Function to create bootable USB
create_bootable_usb() {
    local iso_file="$1"
    local usb_drive="$2"

    echo -e "${YELLOW}Preparing to write ${iso_file} to ${usb_drive}${NC}"
    echo -e "${RED}WARNING: All data on ${usb_drive} will be ERASED!${NC}"
    
    # Double-check with disk information
    echo -e "${YELLOW}Drive information for ${usb_drive}:${NC}"
    lsblk ${usb_drive} -o NAME,SIZE,MODEL,VENDOR,SERIAL,MOUNTPOINT
    
    # Ask user to verify they have the correct drive
    read -p "Is this the correct USB drive? (yes/no): " verify_drive
    if [[ "$verify_drive" != "yes" ]]; then
        echo -e "${RED}Operation cancelled. Please select the correct drive.${NC}"
        exit 1
    fi
    
    read -p "Are you sure you want to continue? All data will be erased. (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 1
    fi

    # Unmount any mounted partitions
    echo -e "${YELLOW}Unmounting any mounted partitions on ${usb_drive}...${NC}"
    umount "${usb_drive}"* 2>/dev/null

    # Check if this is actually a USB drive
    if ! udevadm info --query=property --name="${usb_drive}" | grep -q "ID_BUS=usb"; then
        echo -e "${RED}WARNING: ${usb_drive} does not appear to be a USB device!${NC}"
        read -p "Are you ABSOLUTELY SURE you want to continue? This might be your system drive! (yes/NO): " really_sure
        if [[ "$really_sure" != "yes" ]]; then
            echo -e "${RED}Operation cancelled.${NC}"
            exit 1
        fi
    fi

    # Write ISO to USB drive
    echo -e "${YELLOW}Writing ISO to USB drive (this may take a while)...${NC}"
    dd bs=4M if="${iso_file}" of="${usb_drive}" status=progress oflag=sync
    
    # Sync and verify
    echo -e "${YELLOW}Syncing file system...${NC}"
    sync
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}ISO written successfully to device!${NC}"
        
        # Verify that the boot sector has been written
        echo -e "${YELLOW}Verifying boot sector...${NC}"
        dd if=${usb_drive} bs=512 count=1 | hexdump -C | head -1
        
        echo -e "${GREEN}Bootable USB created successfully!${NC}"
    else
        echo -e "${RED}Failed to create bootable USB.${NC}"
        exit 1
    fi
}

# Function to clean up downloaded ISO file
cleanup_iso() {
    local iso_file="$1"
    
    echo -e "${YELLOW}Cleaning up...${NC}"
    
    # Ask user if they want to remove the ISO file
    read -p "Do you want to remove the downloaded ISO file? (yes/no): " remove_iso
    
    if [[ "$remove_iso" == "yes" ]]; then
        if [ -f "$iso_file" ]; then
            rm -f "$iso_file"
            echo -e "${GREEN}ISO file removed successfully.${NC}"
        else
            echo -e "${RED}ISO file not found.${NC}"
        fi
    else
        echo -e "${YELLOW}ISO file kept at: $(pwd)/${iso_file}${NC}"
    fi
}

# Function to add boot helper script
create_boot_helper() {
    local usb_drive="$1"
    
    echo -e "${YELLOW}Checking for EFI partition on the USB drive...${NC}"
    
    # Get the first partition that might be an EFI partition
    local efi_partition="${usb_drive}1"
    
    # Check if partition exists and has a filesystem
    if [ -b "$efi_partition" ]; then
        local mount_point="/mnt/arch_efi_temp"
        
        # Create temporary mount point
        mkdir -p "$mount_point"
        
        # Try to mount the EFI partition
        if mount "$efi_partition" "$mount_point" 2>/dev/null; then
            echo -e "${GREEN}Found mountable partition. Creating boot helper script...${NC}"
            
            # Create directory for script
            mkdir -p "$mount_point/EFI/BOOT/"
            
            # Create a simple script to help with boot issues
            cat > "$mount_point/EFI/BOOT/README.txt" << 'EOF'
ARCH LINUX BOOT TROUBLESHOOTING
==============================

If your system is not booting from this USB drive:

1. Enter your BIOS/UEFI settings (usually by pressing F2, DEL, F10, or ESC during startup)

2. Check the boot order and ensure USB boot is prioritized

3. If you have Secure Boot enabled, try disabling it

4. Some systems require Legacy/CSM boot mode for bootable USBs

5. Try a different USB port, preferably a USB 2.0 port if available

6. If all else fails, try creating the bootable USB using a different method such as:
   - Rufus (Windows)
   - balenaEtcher (Cross-platform)
   - dd command (Linux)
EOF
            
            # Unmount the partition
            umount "$mount_point"
            
            # Remove the temporary directory
            rmdir "$mount_point"
            
            echo -e "${GREEN}Boot helper information added to the USB drive.${NC}"
        else
            echo -e "${YELLOW}Could not mount EFI partition. Skipping boot helper creation.${NC}"
            rmdir "$mount_point"
        fi
    else
        echo -e "${YELLOW}No suitable partition found for boot helper. Skipping.${NC}"
    fi
}

# Function to copy repository content to USB drive
copy_repo_to_usb() {
    local usb_drive="$1"
    
    echo -e "${YELLOW}Preparing to copy Mango Linux Configuration repository to USB drive...${NC}"
    
    # Find a FAT32 partition on the USB drive that we can write to
    local data_partition=""
    local mount_point="/mnt/arch_data_temp"
    
    # Create mount point directory if it doesn't exist
    mkdir -p "$mount_point"
    
    # Look for partitions on the USB drive
    for partition in "${usb_drive}"*; do
        if [ -b "$partition" ] && [ "$partition" != "$usb_drive" ]; then
            # Try to mount the partition
            if mount "$partition" "$mount_point" 2>/dev/null; then
                # Check if we have write permissions
                if touch "$mount_point/test_write" 2>/dev/null; then
                    rm "$mount_point/test_write"
                    echo -e "${GREEN}Found writable partition: $partition${NC}"
                    data_partition="$partition"
                    break
                fi
                umount "$mount_point"
            fi
        fi
    done
    
    # If no suitable partition is found, we'll create a simple data partition
    if [ -z "$data_partition" ]; then
        echo -e "${YELLOW}No writable partition found. Creating a data partition...${NC}"
        
        # Get the last partition number
        local last_part_num=$(ls -1 "${usb_drive}"* | grep -oE '[0-9]+$' | sort -n | tail -1)
        
        # Create a new simple partition at the end of the drive
        parted -s "$usb_drive" mkpart primary ext4 100% 100%
        
        # Get the new partition name
        if [[ "$usb_drive" == *"nvme"* ]]; then
            data_partition="${usb_drive}p$((last_part_num + 1))"
        else
            data_partition="${usb_drive}$((last_part_num + 1))"
        fi
        
        # Format the partition as ext4
        echo -e "${YELLOW}Formatting data partition as ext4...${NC}"
        mkfs.ext4 -F "$data_partition"
        
        # Mount the new partition
        mount "$data_partition" "$mount_point"
    fi
    
    # Create a directory for the repository
    mkdir -p "$mount_point/mango-linux"
    
    # Get the script directory (where this script is located)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Navigate to the root of the repository (assuming the standard structure)
    local repo_root="$(cd "$script_dir/../.." && pwd)"
    
    echo -e "${GREEN}Copying Mango Linux Configuration repository to USB drive...${NC}"
    echo -e "${YELLOW}Repository source: ${repo_root}${NC}"
    echo -e "${YELLOW}Destination: ${mount_point}/mango-linux${NC}"
    
    # Copy the repository content to the USB drive
    rsync -av --exclude ".git" "$repo_root/" "$mount_point/mango-linux/"
    
    # Create a README file on the USB drive
    cat > "$mount_point/README.txt" << EOF
MANGO LINUX CONFIGURATION
=========================

This USB drive contains:
1. Arch Linux installation media (boot from this USB to install Arch Linux)
2. Mango Linux Configuration repository (in the mango-linux directory)

To use the Mango Linux Configuration tools after booting from this USB:
1. Open a terminal
2. Navigate to the repository directory:
   cd /run/media/arch/mango-linux
   (Note: The actual mount path may vary depending on your system)
3. Run the installation script:
   ./install.sh

For more information, see the README.md file in the mango-linux directory.
EOF
    
    # Create a desktop shortcut file on the USB drive
    mkdir -p "$mount_point/mango-linux/launcher"
    cat > "$mount_point/mango-linux/launcher/mango-linux-install.desktop" << EOF
[Desktop Entry]
Type=Application
Terminal=true
Name=Mango Linux Install
Comment=Launch Mango Linux Installation
Exec=bash -c "cd \$(dirname \$(readlink -f %k))/.. && ./install.sh"
Icon=system-software-install
Categories=System;
EOF
    
    # Make the desktop file executable
    chmod +x "$mount_point/mango-linux/launcher/mango-linux-install.desktop"
    
    # Sync and unmount
    sync
    umount "$mount_point"
    rmdir "$mount_point"
    
    echo -e "${GREEN}Repository successfully copied to USB drive!${NC}"
    echo -e "${GREEN}You can now access the Mango Linux Configuration repository from the USB drive.${NC}"
}

# Main script execution
main() {
    # Check for sudo privileges
    check_sudo
    
    # Check for required dependencies
    check_dependencies

    # Clear screen
    clear

    # ASCII Art Header
    echo -e "${GREEN}"
    echo "   ___             _______  ___  ___  _______   _________  ___  ___       _______  _______   "
    echo "  |\\  \\           /\\   _  \\/\\  \\/\\  \\/\\   _  \\ /\\   _____\\/\\  \\/\\  \\     /\\   _  \\/\\   __  \\ "
    echo "  \\ \\  \\         /  \\  \\L\\ \\ \\  \\_\\  \\ \\  \\L\\ \\\\ \\  \\__/\\_\\ \\  \\\\\\  \\    \\ \\  \\L\\ \\ \\  \\/\\  \\"
    echo "   \\ \\  \\        \\ \\   __  \\ \\  __  \\ \\   __/ \\ \\  \\  \\|_|\\ \\   __  \\    \\ \\   __\\ \\  \\\\\\  \\"
    echo "    \\ \\  \\____    \\ \\  \\/\\  \\ \\  \\/\\  \\ \\  \\/   \\ \\  \\     \\ \\  \\/\\  \\    \\ \\  \\_|\\ \\  \\_\\  \\"
    echo "     \\ \\_______\\   \\ \\__\\/\\__\\ \\__\\/\\__\\ \\__\\    \\ \\__\\     \\ \\__\\/\\__\\    \\ \\_______\\ \\_______\\"
    echo "      \\|_______|    \\|__/\\|__/\\|__/\\|__/\\|__|     \\|__|      \\|__/\\|__|     \\|_______/\\|_______|"
    echo -e "${NC}"
    echo -e "${YELLOW}Arch Linux USB Creator - Mango Linux Configuration Edition${NC}"
    echo -e "${GREEN}Using Arch Linux version: ${ARCH_VERSION}${NC}"
    echo ""

    # List available USB drives
    list_usb_drives

    # Prompt for USB drive
    read -p "Enter the USB drive path (e.g., /dev/sdb): " usb_drive

    # Store the ISO filename
    local iso_filename="archlinux-${ARCH_VERSION}-x86_64.iso"
    
    # Download ISO from MIT mirror
    download_iso

    # Create bootable USB
    create_bootable_usb "$iso_filename" "${usb_drive}"
    
    # Create boot helper information on the USB
    create_boot_helper "${usb_drive}"
    
    # Copy repository content to the USB drive
    copy_repo_to_usb "${usb_drive}"
    
    echo -e "\n${YELLOW}=== BOOT INSTRUCTIONS ===${NC}"
    echo -e "${GREEN}To boot from this USB drive:${NC}"
    echo -e "1. Restart your computer"
    echo -e "2. During startup, press the boot menu key for your system:"
    echo -e "   - Dell: F12"
    echo -e "   - HP: F9"
    echo -e "   - Lenovo: F12 or Fn+F12"
    echo -e "   - ASUS: F8"
    echo -e "   - Acer: F12"
    echo -e "   - MSI: F11"
    echo -e "   - Apple Mac: Hold Option/Alt key"
    echo -e "3. Select the USB drive from the boot menu"
    echo -e "\n${YELLOW}To access Mango Linux Configuration:${NC}"
    echo -e "• After booting into Arch Linux, mount the USB drive"
    echo -e "• Navigate to the mango-linux folder on the USB"
    echo -e "• Run ./install.sh to access all Mango Linux tools\n"
    
    # Clean up the ISO file after successful USB creation
    cleanup_iso "$iso_filename"
}

# Run the main function
main
