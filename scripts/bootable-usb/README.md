# Arch Linux USB Creator

## Overview

A flexible bash script to create a customized bootable Arch Linux USB drive with version and architecture selection.

## Features

- Select specific Arch Linux version
- Choose CPU architecture (x86_64, ARM64, ARM32)
- Automatically downloads selected ISO
- Verifies ISO integrity using GPG
- Lists available USB drives
- Creates a bootable USB drive

## Prerequisites

### Software Dependencies
- wget
- gpg
- dd
- lsblk
- curl
- grep

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
   - Select Arch Linux version (including latest)
   - Choose CPU architecture:
     - x86_64 (Most common, 64-bit Intel/AMD)
     - ARM64 (ARM 64-bit)
     - ARM32 (ARM 32-bit)
   - Select target USB drive
   - Confirm USB drive selection

## Example Workflow

```
Arch Linux USB Creator
----------------------------------------
Available Arch Linux Versions:
0) Latest version
1) 2024.01.01
2) 2023.12.01
...

Select Arch Linux version (0-X): 0

Available CPU Architectures:
1) x86_64 (Most common, 64-bit Intel/AMD)
2) arm64 (ARM 64-bit)
3) armv7 (ARM 32-bit)

Select CPU Architecture (1-3): 1

Available USB Drives:
NAME   SIZE   MODEL
/dev/sdb  16G   SanDisk Cruzer

Enter the USB drive device (e.g., /dev/sdb): /dev/sdb

WARNING: ALL DATA ON /dev/sdb WILL BE ERASED!
Are you sure you want to continue? (y/n): y
```

## Warning

⚠️ **IMPORTANT**: 
- This script will COMPLETELY ERASE the selected USB drive
- Ensure you have backed up any important data on the USB drive
- Carefully select the correct USB drive when prompted

## Troubleshooting

- Ensure all dependencies are installed
- Check internet connection
- Verify USB drive is properly connected
- Run script with sufficient permissions (sudo)
- Verify GPG key if signature verification fails

## License

MIT License
