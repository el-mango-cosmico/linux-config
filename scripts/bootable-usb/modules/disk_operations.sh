#!/bin/bash
# Module: disk_operations.sh
# Handles USB drive operations

# Function to list available USB drives
list_usb_drives() {
    echo -e "${YELLOW}Available USB Drives:${NC}"
    lsblk -do NAME,SIZE,TYPE,MOUNTPOINT | grep -E 'sd[b-z]|usb'
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

# Function to create boot helper script
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
