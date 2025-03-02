#!/bin/bash

# Arch Linux Bootable USB Creator
# This script helps create a bootable USB drive for Arch Linux installation

# Colors for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run this script with sudo or as root${NC}"
        exit 1
    fi
}

# Function to list and select Arch Linux version
select_arch_version() {
    echo -e "${YELLOW}Available Arch Linux Versions:${NC}"
    
    # Fetch available versions (this is a simulated list)
    versions=(
        "2024.03.01"
        "2024.02.01"
        "2023.12.01"
        "2023.11.01"
    )

    # Display versions with numbers
    for i in "${!versions[@]}"; do
        echo "$((i+1)). ${versions[i]}"
    done

    # Prompt for selection
    while true; do
        read -p "Enter the number of the version you want to download (1-${#versions[@]}): " version_choice
        
        if [[ $version_choice =~ ^[0-9]+$ ]] && 
           [ $version_choice -ge 1 ] && 
           [ $version_choice -le ${#versions[@]} ]; then
            selected_version="${versions[$((version_choice-1))]}"
            break
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and ${#versions[@]}.${NC}"
        fi
    done
}

# Function to list available USB drives
list_usb_drives() {
    echo -e "${YELLOW}Available USB Drives:${NC}"
    lsblk -do NAME,SIZE,TYPE,MOUNTPOINT | grep -E 'sd[b-z]|usb'
}

# Function to download Arch Linux ISO
download_iso() {
    local version="$1"
    local iso_url="https://archlinux.org/iso/${version}/archlinux-${version}-x86_64.iso"
    local iso_filename="archlinux-${version}-x86_64.iso"

    echo -e "${GREEN}Downloading Arch Linux ${version}...${NC}"
    wget -O "${iso_filename}" "${iso_url}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Download complete: ${iso_filename}${NC}"
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
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 1
    fi

    # Unmount any mounted partitions
    umount "${usb_drive}"* 2>/dev/null

    # Write ISO to USB drive
    dd bs=4M if="${iso_file}" of="${usb_drive}" status=progress oflag=sync
    
    # Sync and verify
    sync
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Bootable USB created successfully!${NC}"
        echo -e "${YELLOW}You can now boot from ${usb_drive}${NC}"
    else
        echo -e "${RED}Failed to create bootable USB.${NC}"
        exit 1
    fi
}

# Main script execution
main() {
    # Check for sudo privileges
    check_sudo

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

    # Select Arch Linux version
    select_arch_version

    # List available USB drives
    list_usb_drives

    # Prompt for USB drive
    read -p "Enter the USB drive path (e.g., /dev/sdb): " usb_drive

    # Download ISO
    download_iso "${selected_version}"

    # Create bootable USB
    create_bootable_usb "archlinux-${selected_version}-x86_64.iso" "${usb_drive}"
}

# Run the main function
main
