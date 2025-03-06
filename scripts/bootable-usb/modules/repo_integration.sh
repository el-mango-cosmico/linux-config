#!/bin/bash
# Module: repo_integration.sh
# Handles the integration of the repository content into the USB drive

# Function to copy repository content to USB drive
copy_repo_to_usb() {
    local usb_drive="$1"
    local repo_root="$2"
    
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
    
    # Create live environment integration script
    create_live_env_integration "$mount_point"
    
    # Sync and unmount
    sync
    umount "$mount_point"
    rmdir "$mount_point"
    
    echo -e "${GREEN}Repository successfully copied to USB drive!${NC}"
    echo -e "${GREEN}You can now access the Mango Linux Configuration repository from the USB drive.${NC}"
}

# Function to create live environment integration script
create_live_env_integration() {
    local mount_point="$1"
    
    echo -e "${YELLOW}Creating live environment integration script...${NC}"
    
    # Create script to copy repository to home directory in live environment
    cat > "$mount_point/mango-linux/copy-to-home.sh" << 'EOF'
#!/bin/bash

# Script to copy Mango Linux Configuration to home directory in live environment
# This script is automatically executed when using the Live Environment

# Colors for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Mango Linux Configuration - Live Environment Setup${NC}"

# Find the USB drive containing this script
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
REPO_DIR=$(dirname "$SCRIPT_DIR")

# Destination in home directory
HOME_DIR="/home/arch"
DEST_DIR="${HOME_DIR}/mango-linux"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Copy repository to home directory
echo -e "${YELLOW}Copying Mango Linux Configuration to home directory...${NC}"
rsync -av --exclude ".git" "$REPO_DIR/" "$DEST_DIR/"

# Set proper permissions
chown -R arch:arch "$DEST_DIR"
chmod +x "$DEST_DIR/install.sh"

# Create desktop shortcut
mkdir -p "${HOME_DIR}/Desktop"
cat > "${HOME_DIR}/Desktop/mango-linux-install.desktop" << EOD
[Desktop Entry]
Type=Application
Terminal=true
Name=Mango Linux Install
Comment=Launch Mango Linux Installation
Exec=bash -c "cd ${DEST_DIR} && ./install.sh"
Icon=system-software-install
Categories=System;
EOD

# Make the desktop file executable
chmod +x "${HOME_DIR}/Desktop/mango-linux-install.desktop"
chown arch:arch "${HOME_DIR}/Desktop/mango-linux-install.desktop"

echo -e "${GREEN}Setup complete!${NC}"
echo -e "You can now access Mango Linux Configuration at ${DEST_DIR}"
echo -e "Or run it directly from the desktop shortcut"

EOF
    
    # Make the script executable
    chmod +x "$mount_point/mango-linux/copy-to-home.sh"
    
    # Create systemd service to run script at boot in live environment
    mkdir -p "$mount_point/mango-linux/live-setup"
    
    cat > "$mount_point/mango-linux/live-setup/mango-linux-live.service" << EOF
[Unit]
Description=Mango Linux Configuration Live Environment Setup
After=display-manager.service

[Service]
Type=oneshot
ExecStart=/bin/bash /run/media/arch/mango-linux/copy-to-home.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Create readme for live environment integration
    cat > "$mount_point/mango-linux/live-setup/README.md" << EOF
# Live Environment Integration

This directory contains files to integrate Mango Linux Configuration with the Arch Linux live environment.

## Manual Setup

If the automatic integration doesn't work, you can manually set up the environment:

1. Boot from the Arch Linux USB
2. Open a terminal
3. Find and mount the USB drive:
   \`\`\`
   lsblk
   # Find the USB drive (likely /dev/sdb)
   mkdir -p /mnt/usb
   mount /dev/sdX# /mnt/usb  # Replace X# with your USB partition
   \`\`\`
4. Run the copy script:
   \`\`\`
   sudo bash /mnt/usb/mango-linux/copy-to-home.sh
   \`\`\`
5. Navigate to the copied repository:
   \`\`\`
   cd ~/mango-linux
   \`\`\`
6. Run the installation script:
   \`\`\`
   ./install.sh
   \`\`\`

## How It Works

The \`copy-to-home.sh\` script:
1. Copies the Mango Linux Configuration repository to the home directory
2. Creates a desktop shortcut for easy access
3. Sets appropriate permissions

EOF
    
    echo -e "${GREEN}Live environment integration script created!${NC}"
}
