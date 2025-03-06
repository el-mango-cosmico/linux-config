#!/bin/bash

# Mango Linux Configuration - Main Installation Script
# This script serves as the central entrypoint for all Mango Linux configuration options

# Colors for formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if script is run with sufficient permissions
check_permissions() {
    if [[ $1 == "root" && "$(id -u)" -ne 0 ]]; then
        echo -e "${RED}This option requires root privileges. Please run with sudo.${NC}"
        exit 1
    fi
}

# Function to make scripts executable
make_executable() {
    local script_path="$1"
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
    else
        echo -e "${RED}Script not found: $script_path${NC}"
        exit 1
    fi
}

# Display ASCII art header
display_header() {
    clear
    echo -e "${GREEN}"
    echo "   __  ___                            __    _                  "
    echo "  /  |/  /___ _____  ____ _____     / /   (_)___  __  ___  __ "
    echo " / /|_/ / __ \`/ __ \/ __ \`/ __ \   / /   / / __ \/ / / / |/_/ "
    echo "/ /  / / /_/ / / / / /_/ / /_/ /  / /___/ / / / / /_/ />  <   "
    echo "/_/  /_/\__,_/_/ /_/\__, /\____/  /_____/_/_/ /_/\__,_/_/|_|   "
    echo "                   /____/                                      "
    echo -e "${NC}"
    echo -e "${YELLOW}Mango Linux Configuration - Installation Manager${NC}"
    echo -e "${BLUE}A repository for automating the setup and configuration of Arch Linux${NC}"
    echo "-----------------------------------------------------------------------"
}

# Function to run system discovery script
run_system_discovery() {
    echo -e "\n${BLUE}=== System Discovery ===${NC}"
    echo -e "This will analyze your system and recommend the appropriate Arch Linux version.\n"

    local os_type="$(uname -s)"
    if [[ "$os_type" == "Linux" ]]; then
        make_executable "scripts/determine-arch-ver/linux-os-discovery-updated.sh"
        ./scripts/determine-arch-ver/linux-os-discovery-updated.sh
    elif [[ "$os_type" == "MINGW"* ]] || [[ "$os_type" == "MSYS"* ]] || [[ "$os_type" == "CYGWIN"* ]]; then
        echo -e "${YELLOW}Windows detected. Running PowerShell script...${NC}"
        powershell.exe -ExecutionPolicy Bypass -File scripts/determine-arch-ver/windows-os-discovery-updated.ps1
    else
        echo -e "${RED}Unsupported operating system: $os_type${NC}"
        echo -e "${YELLOW}Please manually run one of the following scripts:${NC}"
        echo -e "- scripts/determine-arch-ver/linux-os-discovery-updated.sh (for Linux)"
        echo -e "- scripts/determine-arch-ver/windows-os-discovery-updated.ps1 (for Windows)"
    fi
}

# Function to create bootable USB
create_bootable_usb() {
    echo -e "\n${BLUE}=== Create Bootable USB ===${NC}"
    echo -e "This will create a bootable Arch Linux USB drive.\n"
    
    check_permissions "root"
    make_executable "scripts/bootable-usb/arch-usb-creator.sh"
    
    ./scripts/bootable-usb/arch-usb-creator.sh
}

# Function to install Arch Linux
install_arch_linux() {
    echo -e "\n${BLUE}=== Install Arch Linux ===${NC}"
    echo -e "This will install Arch Linux with a development environment.\n"
    
    check_permissions "root"
    make_executable "scripts/install/arch-install-script.sh"
    
    echo -e "${YELLOW}WARNING: This script should be run from the Arch Linux live environment.${NC}"
    read -p "Are you currently booted into the Arch Linux live environment? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        ./scripts/install/arch-install-script.sh
    else
        echo -e "${RED}Installation aborted. Please boot into the Arch Linux live environment first.${NC}"
    fi
}

# Function to setup root CA
setup_root_ca() {
    echo -e "\n${BLUE}=== Setup Root CA ===${NC}"
    echo -e "This will set up a Root Certificate Authority on YubiKeys.\n"
    
    make_executable "scripts/setup-root-ca/root-ca-setup.sh"
    
    # Check if required tools are installed
    if ! command -v ykman &>/dev/null || ! command -v openssl &>/dev/null; then
        echo -e "${RED}Required tools not found. Please install 'yubikey-manager' and 'openssl'.${NC}"
        read -p "Do you want to install the required packages? (y/n): " install_confirm
        if [[ "$install_confirm" == "y" || "$install_confirm" == "Y" ]]; then
            # Detect package manager and install
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y yubikey-manager openssl
            elif command -v dnf &>/dev/null; then
                sudo dnf install -y yubikey-manager openssl
            elif command -v pacman &>/dev/null; then
                sudo pacman -S --noconfirm yubikey-manager openssl
            else
                echo -e "${RED}Unable to install packages. Please install manually.${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Aborting setup. Please install the required tools manually.${NC}"
            exit 1
        fi
    fi
    
    ./scripts/setup-root-ca/root-ca-setup.sh
}

# Main function
main() {
    display_header
    
    echo -e "\nPlease select an option:"
    echo -e "1) ${BLUE}System Discovery${NC} - Determine appropriate Arch Linux version"
    echo -e "2) ${BLUE}Create Bootable USB${NC} - Create bootable Arch Linux USB drive"
    echo -e "3) ${BLUE}Install Arch Linux${NC} - Full Arch Linux installation"
    echo -e "4) ${BLUE}Setup Root CA${NC} - Set up a Root Certificate Authority"
    echo -e "0) ${BLUE}Exit${NC}"
    
    read -p "Enter your choice [0-4]: " choice
    
    case $choice in
        1)
            run_system_discovery
            ;;
        2)
            create_bootable_usb
            ;;
        3)
            install_arch_linux
            ;;
        4)
            setup_root_ca
            ;;
        0)
            echo -e "${GREEN}Exiting. Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            main
            ;;
    esac
    
    # Ask if user wants to return to main menu
    echo -e "\n"
    read -p "Return to main menu? (y/n): " return_menu
    if [[ "$return_menu" == "y" || "$return_menu" == "Y" ]]; then
        main
    else
        echo -e "${GREEN}Exiting. Goodbye!${NC}"
    fi
}

# Run main function
main
