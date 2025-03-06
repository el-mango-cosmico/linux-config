#!/bin/bash
# live-env-setup.sh
# Script to automatically configure Mango Linux Configuration in the live environment

# Colors for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display header
echo -e "${GREEN}"
echo "   __  ___                            __    _                  "
echo "  /  |/  /___ _____  ____ _____     / /   (_)___  __  ___  __ "
echo " / /|_/ / __ \`/ __ \/ __ \`/ __ \   / /   / / __ \/ / / / |/_/ "
echo "/ /  / / /_/ / / / / /_/ / /_/ /  / /___/ / / / / /_/ />  <   "
echo "/_/  /_/\__,_/_/ /_/\__, /\____/  /_____/_/_/ /_/\__,_/_/|_|   "
echo "                   /____/                                      "
echo -e "${NC}"
echo -e "${YELLOW}Mango Linux Configuration - Live Environment Setup${NC}"
echo -e "${BLUE}Preparing for use in the Arch Linux live environment${NC}"
echo "-----------------------------------------------------------------------"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script with sudo or as root${NC}"
    exit 1
fi

# Function to find USB drive with Mango Linux
find_usb_drive() {
    local found_drive=""
    
    echo -e "${YELLOW}Searching for Mango Linux Configuration USB drive...${NC}"
    
    # Create temporary mount point
    local mount_point="/tmp/mango_usb_temp"
    mkdir -p "$mount_point"
    
    # Check all removable drives
    for drive in /dev/sd*; do
        if [[ $drive =~ /dev/sd[a-z]$ ]]; then
            continue  # Skip disk, only check partitions
        fi
        
        # Try to mount the partition
        if mount "$drive" "$mount_point" 2>/dev/null; then
            # Check if this contains our repository
            if [ -d "$mount_point/mango-linux" ]; then
                found_drive="$drive"
                umount "$mount_point"
                break
            fi
            umount "$mount_point"
        fi
    done
    
    # Remove temporary mount point
    rmdir "$mount_point"
    
    if [ -n "$found_drive" ]; then
        echo -e "${GREEN}Found Mango Linux Configuration on $found_drive${NC}"
        echo "$found_drive"
        return 0
    else
        echo -e "${RED}Could not find Mango Linux Configuration USB drive${NC}"
        return 1
    fi
}

# Function to copy repository to home directory
copy_to_home() {
    local usb_drive="$1"
    local mount_point="/mnt/mango_usb"
    
    # Create mount point
    mkdir -p "$mount_point"
    
    # Mount USB drive
    if ! mount "$usb_drive" "$mount_point"; then
        echo -e "${RED}Failed to mount USB drive${NC}"
        rmdir "$mount_point"
        return 1
    fi
    
    # Define home directory
    local home_dir="/home/arch"
    local dest_dir="${home_dir}/mango-linux"
    
    echo -e "${YELLOW}Copying Mango Linux Configuration to home directory...${NC}"
    
    # Create destination directory
    mkdir -p "$dest_dir"
    
    # Copy repository files
    rsync -av --exclude ".git" "$mount_point/mango-linux/" "$dest_dir/"
    
    # Set proper permissions
    chown -R arch:arch "$dest_dir"
    chmod +x "$dest_dir/install.sh"
    
    # Create desktop shortcut
    mkdir -p "${home_dir}/Desktop"
    cat > "${home_dir}/Desktop/mango-linux-install.desktop" << EOF
[Desktop Entry]
Type=Application
Terminal=true
Name=Mango Linux Install
Comment=Launch Mango Linux Installation
Exec=bash -c "cd ${dest_dir} && ./install.sh"
Icon=system-software-install
Categories=System;
EOF
    
    # Make the desktop file executable
    chmod +x "${home_dir}/Desktop/mango-linux-install.desktop"
    chown arch:arch "${home_dir}/Desktop/mango-linux-install.desktop"
    
    # Unmount the USB drive
    umount "$mount_point"
    rmdir "$mount_point"
    
    echo -e "${GREEN}Setup complete!${NC}"
    echo -e "You can now access Mango Linux Configuration at ${dest_dir}"
    echo -e "Or run it directly from the desktop shortcut"
    
    return 0
}

# Main function
main() {
    echo -e "${YELLOW}Setting up Mango Linux Configuration in live environment...${NC}"
    
    # Find the USB drive
    local usb_drive=$(find_usb_drive)
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Attempting manual search...${NC}"
        
        # List available drives
        echo -e "Available drives:"
        lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT
        
        # Ask user to specify the drive
        read -p "Enter the partition containing Mango Linux (e.g., /dev/sdb1): " usb_drive
        
        if [ ! -b "$usb_drive" ]; then
            echo -e "${RED}Invalid drive specified.${NC}"
            exit 1
        fi
    fi
    
    # Copy repository to home directory
    copy_to_home "$usb_drive"
    
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}Mango Linux Configuration is ready to use!${NC}"
        echo -e "To start, run: cd ~/mango-linux && ./install.sh"
        
        # Create autostart entry for desktop
        if [ -d "/home/arch/.config" ]; then
            mkdir -p "/home/arch/.config/autostart"
            cat > "/home/arch/.config/autostart/mango-welcome.desktop" << EOF
[Desktop Entry]
Type=Application
Terminal=true
Name=Mango Linux Welcome
Comment=Welcome to Mango Linux Configuration
Exec=bash -c "echo -e '\033[0;32mWelcome to Mango Linux Configuration!\033[0m\nThe configuration tools are available in ~/mango-linux\nRun ./install.sh to get started.'"
Icon=system-software-install
Categories=System;
EOF
            chmod +x "/home/arch/.config/autostart/mango-welcome.desktop"
            chown -R arch:arch "/home/arch/.config/autostart"
        fi
    else
        echo -e "${RED}Failed to set up Mango Linux Configuration.${NC}"
        exit 1
    fi
}

# Run the main function
main