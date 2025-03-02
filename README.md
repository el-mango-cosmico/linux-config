# Mango Linux Configuration

A repository for automating the setup and configuration of Arch Linux with custom tools, settings, and configurations.

## Repository Structure

```
.
├── README.md
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

## Bootable USB Creation

Create a bootable Arch Linux USB drive directly from the repository root:

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

## System Discovery Scripts

The repository includes scripts to analyze your system and recommend the appropriate Arch Linux version to install.

## Installation Script

A comprehensive Arch Linux installation script is provided to automate the setup of a development environment.

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
