# Determine Arch Linux Version

These scripts analyze your system and automatically recommend the appropriate Arch Linux version to install based on your hardware specifications.

## Available Scripts

- `linux-os-discovery.sh`: For users currently running Linux systems
- `windows-os-discovery.ps1`: For users currently running Windows systems

## For Linux Users

```bash
# Make the script executable
chmod +x linux-os-discovery.sh

# Run the script
./linux-os-discovery.sh
```

## For Windows Users

```powershell
# Open PowerShell as Administrator
# You may need to change execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run the script
.\windows-os-discovery.ps1
```

## What These Scripts Do

These scripts perform a comprehensive analysis of your system hardware and provide:

1. An immediate recommendation for which Arch Linux version to install
2. Custom installation notes specific to your hardware

### Information Analyzed

- **CPU Architecture**: x86_64, i686, ARM variants
- **CPU Type**: Intel, AMD, or ARM processors
- **Boot Mode**: UEFI vs Legacy BIOS
- **Memory**: Available RAM
- **Graphics**: GPU vendor (NVIDIA, AMD, Intel)
- **Virtualization**: If running in a virtual environment

## Arch Linux Version Selection Logic

The scripts use this system information to recommend:

1. **Standard Arch Linux (x86_64)**: For modern 64-bit Intel/AMD systems
2. **Arch Linux 32**: For legacy 32-bit systems or very low RAM systems
3. **Arch Linux ARM**: For various ARM architectures (aarch64, armv7, etc.)

### Additional Recommendations

- Boot mode specific instructions (UEFI vs Legacy)
- CPU microcode packages (intel-ucode or amd-ucode)
- GPU driver recommendations
- Desktop environment suggestions based on available RAM
- For Windows users: Dual-boot considerations and preparation steps

## Understanding System Requirements for Arch Linux

Based on the information collected, the scripts interpret:

1. **CPU Architecture**:
   - x86_64: Standard for most modern computers
   - i686: Legacy 32-bit architecture
   - ARM: For compatible devices like Raspberry Pi

2. **Boot Mode**:
   - UEFI: Modern boot method
   - Legacy BIOS: Older boot method

3. **Memory Requirements**:
   - Minimal: 512MB RAM (CLI only)
   - Desktop Environment: 1GB+ RAM
   - Modern desktop usage: 2GB+ recommended

## Next Steps

After receiving your Arch Linux version recommendation:

1. Download the appropriate Arch Linux ISO from [archlinux.org](https://archlinux.org/download/)
2. Create bootable media using tools like Rufus (Windows) or dd (Linux)
3. Boot from the installation media
4. Follow the Arch Linux installation guide, referring to your specific recommendations

## Troubleshooting

- **Permission denied**: Make sure to run with appropriate permissions (sudo for Linux, Administrator for Windows)
- **Execution policy errors**: On Windows, you may need to adjust PowerShell execution policy

## Contributing

Feel free to submit pull requests or suggest improvements to these scripts.
