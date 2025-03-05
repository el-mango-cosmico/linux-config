#!/bin/bash

# Arch Linux Bootable USB Creator
# This script helps create a bootable USB drive for Arch Linux installation

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
    local deps=("wget" "dd" "grep")
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
    lsblk -do NAME,SIZE,TYPE,MOUNTPOINT | grep -E 'sd[b-z]|usb'
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
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${RED}Operation cancelled.${NC}"
        exit 1
    fi

    # Unmount any mounted partitions
    echo -e "${YELLOW}Unmounting any mounted partitions on ${usb_drive}...${NC}"
    umount "${usb_drive}"* 2>/dev/null

    # Write ISO to USB drive
    echo -e "${YELLOW}Writing ISO to USB drive (this may take a while)...${NC}"
    dd bs=4M if="${iso_file}" of="${usb_drive}" status=progress oflag=sync
    
    # Sync and verify
    echo -e "${YELLOW}Syncing file system...${NC}"
    sync
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Bootable USB created successfully!${NC}"
        echo -e "${YELLOW}You can now boot from ${usb_drive}${NC}"
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
    echo -e "${YELLOW}Arch Linux USB Creator - MIT Mirror Edition${NC}"
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
    
    # Clean up the ISO file after successful USB creation
    cleanup_iso "$iso_filename"
}

# Run the main function
main
