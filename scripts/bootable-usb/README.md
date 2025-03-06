# Arch Linux USB Creator

## Overview

A modular bash script system to create a customized bootable Arch Linux USB drive with version and architecture selection, including integrated Mango Linux Configuration.

## Features

- Modular architecture for easier maintenance
- Select specific Arch Linux version
- Automatically downloads selected ISO
- Lists available USB drives
- Creates a bootable USB drive
- Integrates Mango Linux Configuration for use in live environment
- Provides desktop shortcuts for easy access

## Directory Structure

```
scripts/bootable-usb/
├── arch-usb-creator.sh        # Main script
├── live-env-setup.sh          # Script for live environment integration
├── modules/                   # Modular components
│   ├── check_dependencies.sh  # Dependency checking
│   ├── disk_operations.sh     # USB drive operations
│   ├── iso_handling.sh        # ISO download and verification
│   └── repo_integration.sh    # Repository integration
└── README.md                  # This documentation
```

## Prerequisites

### Software Dependencies
- wget
- dd
- grep
- rsync

### Recommended System
- Any Linux distribution
- Root/sudo access
- Internet connection

## Usage

1. Make the script executable:
   ```bash
   chmod +x arch-usb-creator.sh
   ```

2. Run with sudo:
   ```bash
   sudo ./arch-usb-creator.sh
   ```

3. Interactive Prompts
   - Select target USB drive
   - Confirm USB drive selection
   - Choose whether to keep the ISO file

## Live Environment Integration

The created USB drive includes functionality to copy the Mango Linux Configuration repository to the home directory when booting from the live environment.

### Automatic Integration

When booting from the Arch Linux live environment, the system will:
1. Look for the Mango Linux Configuration USB drive
2. Copy the repository to the home directory
3. Create a desktop shortcut for easy access

### Manual Integration

If automatic integration doesn't work:
1. Boot from the Arch Linux USB
2. Open a terminal
3. Run the following command:
   ```bash
   sudo /run/media/arch/*/mango-linux/live-env-setup.sh
   ```

## Warning

⚠️ **IMPORTANT**: 
- This script will COMPLETELY ERASE the selected USB drive
- Ensure you have backed up any important data on the USB drive
- Carefully select the correct USB drive when prompted

## Customization

- To change the Arch Linux version, edit the `ARCH_VERSION` variable in `arch-usb-creator.sh`
- To modify the repository integration process, edit the `copy_repo_to_usb` function in `modules/repo_integration.sh`

## Troubleshooting

- Ensure all dependencies are installed
- Check internet connection
- Verify USB drive is properly connected
- Run script with sufficient permissions (sudo)
