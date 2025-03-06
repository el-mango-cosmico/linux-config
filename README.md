# Mango Linux Configuration

A repository for automating the setup and configuration of Arch Linux with custom tools, settings, and configurations.

## Quick Start

The easiest way to get started is to use the main installation script:

```bash
# Make the script executable (first-time only)
chmod +x install.sh

# Run the installation script
./install.sh
```

The installation script provides a menu to access all available tools:
- System Discovery - Determine appropriate Arch Linux version for your hardware
- Create Bootable USB - Create a bootable Arch Linux USB drive
- Install Arch Linux - Full Arch Linux installation
- Setup Root CA - Set up a Root Certificate Authority on YubiKeys

## Repository Structure

```
.
├── README.md
├── install.sh       # Main installation script
├── config
│   ├── git
│   ├── intellij
│   ├── kde
│   ├── neovim
│   ├── starship
│   └── zsh
├── docs
│   ├── customization
│   ├── installation
│   └── troubleshooting
├── dotfiles
└── scripts
    ├── bootable-usb
    │   ├── README.md                # Documentation for USB creation scripts
    │   └── arch-usb-creator.sh      # Script for creating bootable Arch Linux USB drives
    ├── determine-arch-ver
    │   ├── linux-os-discovery-updated.sh    # System info discovery for Linux
    │   ├── README.md                # Detailed instructions for discovery scripts
    │   └── windows-os-discovery-updated.ps1 # System info discovery for Windows
    ├── install
    │   ├── README.md                # Documentation for Arch Linux installation script
    │   └── arch-install-script.sh   # Comprehensive Arch Linux installation script
    ├── post-install
    ├── setup-root-ca
    │   └── root-ca-setup.sh
    └── utils
```

## Individual Script Usage

If you prefer to run individual scripts directly, you can use the following commands:

### System Discovery Scripts

Determine the appropriate Arch Linux version to install based on your hardware specifications:

#### For Linux Users

```bash
# Make the script executable (first-time only)
chmod +x scripts/determine-arch-ver/linux-os-discovery-updated.sh

# Run the discovery script
./scripts/determine-arch-ver/linux-os-discovery-updated.sh
```

#### For Windows Users

```powershell
# Open PowerShell as Administrator
# You may need to change execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run the discovery script
.\scripts\determine-arch-ver\windows-os-discovery-updated.ps1
```

These scripts analyze your system hardware and provide:
- An immediate recommendation for which Arch Linux version to install
- Custom installation notes specific to your hardware

For detailed usage and requirements, refer to `scripts/determine-arch-ver/README.md`.

### Bootable USB Creation

Create a bootable Arch Linux USB drive:

```bash
# Make the script executable (first-time only)
chmod +x scripts/bootable-usb/arch-usb-creator.sh

# Run the USB creator
sudo ./scripts/bootable-usb/arch-usb-creator.sh
```

Key features:
- Select specific Arch Linux version
- Choose CPU architecture (x86_64, ARM64, ARM32)
- Automatic ISO download and verification
- Detailed system compatibility options

⚠️ **Warning**: The script will ERASE all data on the selected USB drive.

For detailed usage and requirements, refer to `scripts/bootable-usb/README.md`.

### Installation Script

A comprehensive Arch Linux installation script is provided to automate the setup of a development environment.

```bash
# Make the script executable (first-time only)
chmod +x scripts/install/arch-install-script.sh

# Run the installation script
sudo ./scripts/install/arch-install-script.sh
```

### Root CA Setup

Set up a Root Certificate Authority with YubiKey support:

```bash
# Make the script executable (first-time only)
chmod +x scripts/setup-root-ca/root-ca-setup.sh

# Run the setup script
./scripts/setup-root-ca/root-ca-setup.sh
```

## Future Enhancements

This repository will continue to be expanded to include:
- More comprehensive system configuration scripts
- Enhanced dotfiles and configuration management
- Additional system utility scripts
- Expanded support for development environments
- Improved hardware detection and compatibility scripts

## Contributing

Feel free to submit pull requests or suggest improvements to these scripts.

## License

This project is open source and available under the [MIT License](LICENSE).
