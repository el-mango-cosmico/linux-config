#!/bin/bash

# Arch Linux Development Environment Installation Script
# This script automates the installation of Arch Linux with KDE Plasma and development tools

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/tmp/arch_install.log"

# Function to log messages
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Function to display error messages and exit
error_exit() {
    log "$1" "ERROR"
    exit 1
}

# Function to check if command executed successfully
check_success() {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# Function to display section headers
section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
    log "Starting section: $1" "SECTION"
}

# Function to confirm action
confirm() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    error_exit "This script must be run as root"
fi

# Check if running in Arch Linux live environment
if ! grep -q "Arch Linux" /etc/os-release; then
    error_exit "This script must be run in an Arch Linux live environment"
fi

# Display welcome message
clear
echo -e "${GREEN}Welcome to the Arch Linux Development Environment Installation Script${NC}"
echo -e "This script will install and configure Arch Linux with the following components:"
echo -e "- KDE Plasma desktop environment"
echo -e "- Development tools (Python, IntelliJ, Neovim, etc.)"
echo -e "- Browsers and Office applications"
echo -e "- Gaming software (Steam, Lutris)"
echo -e "- Various utilities and tools"
echo
echo -e "${YELLOW}IMPORTANT: This script will format the selected disk. Make sure you have backups of important data.${NC}"
echo

# Confirm installation
if ! confirm "Do you want to proceed with the installation?"; then
    echo "Installation aborted."
    exit 0
fi

# Function to check and setup network connection
setup_network() {
    section "Network Setup"
    
    # Check if network is available
    if ping -c 1 archlinux.org > /dev/null 2>&1; then
        log "Network is already configured and working"
        return 0
    fi
    
    log "Network not available, attempting to configure..."
    
    # Ask user for network configuration method
    echo "Network connection methods:"
    echo "1) Wired (DHCP)"
    echo "2) Wireless (Wi-Fi)"
    read -p "Select network connection method (1-2): " network_choice
    
    case $network_choice in
        1)
            log "Setting up wired connection with DHCP"
            dhcpcd
            check_success "Failed to configure wired network connection"
            ;;
        2)
            log "Setting up wireless connection"
            iwctl
            check_success "Failed to configure wireless network connection"
            ;;
        *)
            error_exit "Invalid network connection method selected"
            ;;
    esac
    
    # Verify network connection
    if ! ping -c 1 archlinux.org > /dev/null 2>&1; then
        error_exit "Network configuration failed. Please configure network manually and restart the script."
    fi
    
    log "Network configured successfully"
}

# Function to setup disk partitioning
setup_disk() {
    section "Disk Setup"
    
    # List available disks
    echo "Available disks:"
    lsblk -pdo NAME,SIZE,MODEL
    
    # Ask user for target disk
    read -p "Enter the disk to install Arch Linux (e.g., /dev/sda): " target_disk
    
    # Verify disk exists
    if [ ! -b "$target_disk" ]; then
        error_exit "Invalid disk: $target_disk"
    fi
    
    echo -e "${RED}WARNING: All data on $target_disk will be erased!${NC}"
    if ! confirm "Are you sure you want to continue?"; then
        error_exit "Disk setup aborted."
    fi
    
    # Ask about partitioning scheme
    echo "Partitioning schemes:"
    echo "1) UEFI with GPT (recommended for modern systems)"
    echo "2) BIOS with MBR (for legacy systems)"
    read -p "Select partitioning scheme (1-2): " part_scheme
    
    # Ask for swap size
    read -p "Enter swap size in GB (recommended: RAM size if < 8GB, 8GB if RAM > 8GB): " swap_size
    
    # Create partitions based on chosen scheme
    if [ "$part_scheme" -eq 1 ]; then
        log "Creating UEFI/GPT partitions"
        
        # Wipe disk
        wipefs -a "$target_disk"
        check_success "Failed to wipe disk"
        
        # Create GPT partition table
        parted -s "$target_disk" mklabel gpt
        check_success "Failed to create GPT partition table"
        
        # Create EFI partition (550MB)
        parted -s "$target_disk" mkpart "EFI" fat32 1MiB 551MiB
        parted -s "$target_disk" set 1 esp on
        
        # Create swap partition
        parted -s "$target_disk" mkpart "swap" linux-swap 551MiB "$((551 + ($swap_size * 1024)))MiB"
        
        # Create root partition (rest of disk)
        parted -s "$target_disk" mkpart "root" ext4 "$((551 + ($swap_size * 1024)))MiB" 100%
        
        # Get partition names
        if [[ "$target_disk" == *"nvme"* ]]; then
            efi_part="${target_disk}p1"
            swap_part="${target_disk}p2"
            root_part="${target_disk}p3"
        else
            efi_part="${target_disk}1"
            swap_part="${target_disk}2"
            root_part="${target_disk}3"
        fi
        
        # Format partitions
        log "Formatting partitions"
        mkfs.fat -F32 "$efi_part"
        check_success "Failed to format EFI partition"
        
        mkswap "$swap_part"
        check_success "Failed to create swap"
        swapon "$swap_part"
        
        mkfs.ext4 -F "$root_part"
        check_success "Failed to format root partition"
        
        # Mount partitions
        log "Mounting partitions"
        mount "$root_part" /mnt
        check_success "Failed to mount root partition"
        
        mkdir -p /mnt/boot/efi
        mount "$efi_part" /mnt/boot/efi
        check_success "Failed to mount EFI partition"
        
    elif [ "$part_scheme" -eq 2 ]; then
        log "Creating BIOS/MBR partitions"
        
        # Wipe disk
        wipefs -a "$target_disk"
        check_success "Failed to wipe disk"
        
        # Create MBR partition table
        parted -s "$target_disk" mklabel msdos
        check_success "Failed to create MBR partition table"
        
        # Create swap partition
        parted -s "$target_disk" mkpart primary linux-swap 1MiB "$((1 + ($swap_size * 1024)))MiB"
        
        # Create root partition (rest of disk)
        parted -s "$target_disk" mkpart primary ext4 "$((1 + ($swap_size * 1024)))MiB" 100%
        parted -s "$target_disk" set 2 boot on
        
        # Get partition names
        if [[ "$target_disk" == *"nvme"* ]]; then
            swap_part="${target_disk}p1"
            root_part="${target_disk}p2"
        else
            swap_part="${target_disk}1"
            root_part="${target_disk}2"
        fi
        
        # Format partitions
        log "Formatting partitions"
        mkswap "$swap_part"
        check_success "Failed to create swap"
        swapon "$swap_part"
        
        mkfs.ext4 -F "$root_part"
        check_success "Failed to format root partition"
        
        # Mount partitions
        log "Mounting partitions"
        mount "$root_part" /mnt
        check_success "Failed to mount root partition"
    else
        error_exit "Invalid partitioning scheme selected"
    fi
    
    log "Disk partitioning completed successfully"
}

# Function to install base system
install_base() {
    section "Installing Base System"
    
    # Update mirror list
    log "Updating mirror list"
    pacman -Sy --noconfirm reflector
    reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
    check_success "Failed to update mirror list"
    
    # Install base packages
    log "Installing base packages"
    pacstrap /mnt base base-devel linux linux-firmware \
             vim nano sudo networkmanager dhcpcd dialog wpa_supplicant \
             intel-ucode amd-ucode dosfstools
    check_success "Failed to install base packages"
    
    # Generate fstab
    log "Generating fstab"
    genfstab -U /mnt >> /mnt/etc/fstab
    check_success "Failed to generate fstab"
    
    log "Base system installation completed"
}

# Function to configure the base system
configure_base() {
    section "Configuring Base System"
    
    # Set timezone
    log "Setting timezone"
    read -p "Enter your timezone (e.g., America/New_York): " timezone
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime
    arch-chroot /mnt hwclock --systohc
    
    # Configure locale
    log "Configuring locale"
    echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen
    echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
    
    # Set hostname
    log "Setting hostname"
    read -p "Enter hostname: " hostname
    echo "$hostname" > /mnt/etc/hostname
    
    # Configure hosts file
    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF
    
    # Set root password
    log "Setting root password"
    echo "Please set the root password:"
    arch-chroot /mnt passwd
    
    # Create user
    log "Creating user"
    read -p "Enter username: " username
    arch-chroot /mnt useradd -m -G wheel,storage,power,video,audio -s /bin/bash "$username"
    echo "Please set the password for $username:"
    arch-chroot /mnt passwd "$username"
    
    # Configure sudo
    log "Configuring sudo"
    sed -i '/%wheel ALL=(ALL) ALL/s/^# //' /mnt/etc/sudoers
    
    # Enable NetworkManager
    log "Enabling NetworkManager"
    arch-chroot /mnt systemctl enable NetworkManager
    
    log "Base system configuration completed"
}

# Function to install and configure bootloader
install_bootloader() {
    section "Installing Bootloader"
    
    if [ -d "/mnt/boot/efi" ]; then
        # UEFI system
        log "Installing GRUB for UEFI"
        arch-chroot /mnt pacman -S --noconfirm grub efibootmgr
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    else
        # BIOS system
        log "Installing GRUB for BIOS"
        read -p "Enter the disk to install GRUB (e.g., /dev/sda): " grub_disk
        arch-chroot /mnt pacman -S --noconfirm grub
        arch-chroot /mnt grub-install --target=i386-pc "$grub_disk"
    fi
    
    # Configure GRUB
    log "Configuring GRUB"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    check_success "Failed to configure GRUB"
    
    log "Bootloader installation completed"
}

# Function to install KDE Plasma desktop environment
install_kde() {
    section "Installing KDE Plasma"
    
    # Install X.org server
    log "Installing X.org server"
    arch-chroot /mnt pacman -S --noconfirm xorg xorg-server
    
    # Install KDE Plasma
    log "Installing KDE Plasma desktop environment"
    arch-chroot /mnt pacman -S --noconfirm plasma-meta kde-applications
    
    # Install SDDM display manager
    log "Installing SDDM display manager"
    arch-chroot /mnt pacman -S --noconfirm sddm
    arch-chroot /mnt systemctl enable sddm
    
    # Install additional useful KDE apps
    log "Installing additional KDE applications"
    arch-chroot /mnt pacman -S --noconfirm \
        dolphin konsole kate ark kfind \
        kcalc spectacle okular gwenview
    
    log "KDE Plasma installation completed"
}

# Function to install AUR helper (yay)
install_aur_helper() {
    section "Installing AUR Helper (yay)"
    
    # Install Git
    arch-chroot /mnt pacman -S --noconfirm git
    
    # Clone and build yay
    arch-chroot /mnt bash -c "cd /home/$username && sudo -u $username git clone https://aur.archlinux.org/yay.git"
    arch-chroot /mnt bash -c "cd /home/$username/yay && sudo -u $username makepkg -si --noconfirm"
    arch-chroot /mnt rm -rf "/home/$username/yay"
    
    log "AUR helper installation completed"
}

# Function to install development tools
install_dev_tools() {
    section "Installing Development Tools"
    
    # Install Python and related tools
    log "Installing Python and related tools"
    arch-chroot /mnt pacman -S --noconfirm python python-pip python-setuptools python-wheel
    
    # Install Poetry and uv for Python package management
    log "Installing Poetry and uv for Python package management"
    arch-chroot /mnt bash -c "sudo -u $username yay -S --noconfirm python-poetry"
    arch-chroot /mnt bash -c "sudo -u $username pip install uv"
    
    # Install Neovim and dependencies
    log "Installing Neovim"
    arch-chroot /mnt pacman -S --noconfirm neovim python-pynvim nodejs npm ripgrep fd
    
    # Install IntelliJ Community Edition
    log "Installing IntelliJ Community Edition"
    arch-chroot /mnt pacman -S --noconfirm intellij-idea-community-edition
    
    # Install development libraries and tools
    log "Installing development libraries and tools"
    arch-chroot /mnt pacman -S --noconfirm \
        base-devel git cmake gcc clang gdb \
        jdk-openjdk maven gradle \
        docker docker-compose \
        sqlite mariadb \
        curl wget htop
    
    # Enable Docker service
    arch-chroot /mnt systemctl enable docker.service
    
    log "Development tools installation completed"
}

# Function to install Oh My Zsh and Starship
install_shell_tools() {
    section "Installing Shell Tools"
    
    # Install Zsh
    log "Installing Zsh"
    arch-chroot /mnt pacman -S --noconfirm zsh
    
    # Install Oh My Zsh
    log "Installing Oh My Zsh"
    arch-chroot /mnt bash -c "cd /home/$username && sudo -u $username sh -c \"\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" '' --unattended"
    
    # Change default shell to Zsh
    arch-chroot /mnt chsh -s /bin/zsh "$username"
    
    # Install Starship prompt
    log "Installing Starship prompt"
    arch-chroot /mnt bash -c "cd /home/$username && sudo -u $username curl -sS https://starship.rs/install.sh | sh -s -- -y"
    
    # Configure Starship
    mkdir -p /mnt/home/$username/.config
    cat > /mnt/home/$username/.config/starship.toml << 'EOF'
# Starship configuration
format = """
[](#9A348E)\
$username\
[](bg:#DA627D fg:#9A348E)\
$directory\
[](fg:#DA627D bg:#FCA17D)\
$git_branch\
$git_status\
[](fg:#FCA17D bg:#86BBD8)\
$python\
$rust\
$golang\
$nodejs\
[](fg:#86BBD8 bg:#06969A)\
$docker_context\
[](fg:#06969A bg:#33658A)\
$time\
[ ](fg:#33658A)\
"""

# Disable the blank line at the start of the prompt
add_newline = false

[username]
show_always = true
style_user = "bg:#9A348E fg:#FFFFFF"
style_root = "bg:#9A348E fg:#FFFFFF"
format = '[$user ]($style)'

[directory]
style = "bg:#DA627D fg:#FFFFFF"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[git_branch]
symbol = ""
style = "bg:#FCA17D fg:#000000"
format = '[ $symbol $branch ]($style)'

[git_status]
style = "bg:#FCA17D fg:#000000"
format = '[$all_status$ahead_behind ]($style)'

[python]
symbol = " "
style = "bg:#86BBD8 fg:#000000"
format = '[ $symbol ($version) ]($style)'

[rust]
symbol = " "
style = "bg:#86BBD8 fg:#000000"
format = '[ $symbol ($version) ]($style)'

[golang]
symbol = " "
style = "bg:#86BBD8 fg:#000000"
format = '[ $symbol ($version) ]($style)'

[nodejs]
symbol = " "
style = "bg:#86BBD8 fg:#000000"
format = '[ $symbol ($version) ]($style)'

[docker_context]
symbol = " "
style = "bg:#06969A fg:#FFFFFF"
format = '[ $symbol $context ]($style)'

[time]
disabled = false
time_format = "%R" # Hour:Minute Format
style = "bg:#33658A fg:#FFFFFF"
format = '[ $time ]($style)'
EOF
    
    # Set proper permissions
    arch-chroot /mnt chown -R "$username:$username" "/home/$username/.config"
    
    # Configure .zshrc to use Starship
    echo 'eval "$(starship init zsh)"' >> /mnt/home/$username/.zshrc
    
    # Install Ghostty terminal (if available in AUR)
    log "Installing Ghostty terminal"
    arch-chroot /mnt bash -c "sudo -u $username yay -S --noconfirm ghostty || echo 'Ghostty not found in AUR, skipping...'"
    
    log "Shell tools installation completed"
}

# Function to install browsers and office applications
install_browsers_office() {
    section "Installing Browsers and Office Applications"
    
    # Install Brave Browser
    log "Installing Brave Browser"
    arch-chroot /mnt bash -c "sudo -u $username yay -S --noconfirm brave-bin"
    
    # Install LibreOffice
    log "Installing LibreOffice"
    arch-chroot /mnt pacman -S --noconfirm libreoffice-fresh libreoffice-fresh-en-us
    
    log "Browsers and office applications installation completed"
}

# Function to install utilities
install_utilities() {
    section "Installing Utilities"
    
    # Install Ark (zip manager)
    log "Installing Ark (zip manager)"
    arch-chroot /mnt pacman -S --noconfirm ark p7zip unrar unzip zip
    
    # Install network tools
    log "Installing network tools"
    arch-chroot /mnt pacman -S --noconfirm \
        net-tools inetutils dnsutils traceroute \
        nmap wireshark-qt ethtool iperf3
    
    # Install Obsidian
    log "Installing Obsidian"
    arch-chroot /mnt bash -c "sudo -u $username yay -S --noconfirm obsidian"
    
    # Install Bitwarden
    log "Installing Bitwarden"
    arch-chroot /mnt bash -c "sudo -u $username yay -S --noconfirm bitwarden-bin"
    
    # Install Cider (Apple Music client)
    log "Installing Cider (Apple Music client)"
    arch-chroot /mnt bash -c "sudo -u $username yay -S --noconfirm cider"
    
    log "Utilities installation completed"
}

# Function to install gaming software
install_gaming() {
    section "Installing Gaming Software"
    
    # Enable multilib repository
    if ! grep -q "^\[multilib\]" /mnt/etc/pacman.conf; then
        log "Enabling multilib repository"
        cat >> /mnt/etc/pacman.conf << EOF

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
        arch-chroot /mnt pacman -Sy
    fi
    
    # Install Steam
    log "Installing Steam"
    arch-chroot /mnt pacman -S --noconfirm steam
    
    # Install Lutris
    log "Installing Lutris"
    arch-chroot /mnt pacman -S --noconfirm lutris wine-staging giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal v4l-utils lib32-v4l-utils libpulse lib32-libpulse libgpg-error lib32-libgpg-error alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib libjpeg-turbo lib32-libjpeg-turbo sqlite lib32-sqlite libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt libva lib32-libva gtk3 lib32-gtk3 gst-plugins-base-libs lib32-gst-plugins-base-libs vulkan-icd-loader lib32-vulkan-icd-loader
    
    log "Gaming software installation completed"
}

# Function to install optional components
install_optional() {
    section "Installing Optional Components"
    
    # Ask about YubiKey setup
    if confirm "Do you want to install YubiKey support?"; then
        log "Installing YubiKey support"
        arch-chroot /mnt pacman -S --noconfirm \
            yubikey-personalization yubikey-manager \
            libusb-compat pam-u2f
        
        # Create udev rules for YubiKey
        cat > /mnt/etc/udev/rules.d/70-yubikey.rules << EOF
# Udev rules for YubiKey
ACTION=="add|change", SUBSYSTEM=="usb", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0113|0114|0115|0116|0120|0200|0402|0403|0406|0407|0410", TAG+="uaccess"
EOF
        
        # Reload udev rules
        arch-chroot /mnt udevadm control --reload-rules
        arch-chroot /mnt udevadm trigger
    fi
    
    # Ask about Podman setup
    if confirm "Do you want to install Podman with Docker compatibility?"; then
        log "Installing Podman with Docker compatibility"
        
        # Install Podman
        arch-chroot /mnt pacman -S --noconfirm podman podman-docker podman-compose
        
        # Create Docker compatibility alias
        cat >> /mnt/home/$username/.zshrc << EOF

# Docker compatibility for Podman
alias docker=podman
alias docker-compose=podman-compose
EOF
        
        # Set proper permissions
        arch-chroot /mnt chown "$username:$username" "/home/$username/.zshrc"
    fi
    
    log "Optional components installation completed"
}

# Function to perform final configurations
final_config() {
    section "Performing Final Configurations"
    
    # Enable services
    log "Enabling essential services"
    arch-chroot /mnt systemctl enable NetworkManager.service
    
    # Update the system
    log "Updating the system"
    arch-chroot /mnt pacman -Syu --noconfirm
    
    # Clean up
    log "Cleaning up"
    arch-chroot /mnt pacman -Sc --noconfirm
    
    log "Final configurations completed"
}

# Main installation flow
main() {
    # Start logging
    echo "" > "$LOG_FILE"
    log "Starting Arch Linux Development Environment Installation"
    
    # Setup steps
    setup_network
    setup_disk
    install_base
    configure_base
    install_bootloader
    install_kde
    install_aur_helper
    install_dev_tools
    install_shell_tools
    install_browsers_office
    install_utilities
    install_gaming
    install_optional
    final_config
    
    # Installation completed
    section "Installation Completed"
    log "Arch Linux development environment has been successfully installed!"
    
    # Unmount partitions
    umount -R /mnt
    
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "You can now reboot your system and log in to your new Arch Linux installation."
    echo -e "Log file is available at: $LOG_FILE"
    
    if confirm "Do you want to reboot now?"; then
        reboot
    fi
}

# Run main function
main
