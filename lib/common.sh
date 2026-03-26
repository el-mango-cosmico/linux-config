#!/bin/bash
# Shared utilities for linux-config modules
# Source this file at the top of any module script: source "$(dirname "$0")/../../lib/common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[ OK ]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ ERR]${NC} $*"; }
log_section() { echo -e "\n${CYAN}${BOLD}=== $* ===${NC}"; }

# Prompt yes/no — returns 0 for yes, 1 for no
# Usage: confirm "Do the thing?" [y|n]  (default answer)
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-y}"
    local yn_prompt="[Y/n]"
    [[ "$default" == "n" ]] && yn_prompt="[y/N]"
    read -rp "$(echo -e "${YELLOW}${prompt} ${yn_prompt}: ${NC}")" answer
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Check if a command exists
check_command() { command -v "$1" &>/dev/null; }

# Install a pacman package if not already installed
# Usage: install_pkg neovim [aur]
install_pkg() {
    local pkg="$1"
    local aur="${2:-}"
    if pacman -Qq "$pkg" &>/dev/null; then
        log_info "$pkg is already installed"
        return 0
    fi
    log_info "Installing $pkg..."
    if [[ "$aur" == "aur" ]]; then
        if check_command paru; then
            paru -S --noconfirm "$pkg"
        elif check_command yay; then
            yay -S --noconfirm "$pkg"
        else
            log_error "No AUR helper found (tried paru, yay). Install one and retry."
            return 1
        fi
    else
        sudo pacman -S --noconfirm "$pkg"
    fi
}

# Deploy a single dotfile as a symlink.
# Prompts the user when the destination already exists as a real file.
# Usage: deploy_file /abs/path/to/source /abs/path/to/destination
deploy_file() {
    local src="$1"
    local dest="$2"

    # Already a symlink pointing at us — nothing to do
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_info "Already linked: $dest"
        return 0
    fi

    if [[ -e "$dest" ]]; then
        local is_dir=""
        [[ -d "$dest" ]] && is_dir=" ${RED}(DIRECTORY — backup strongly recommended)${NC}"
        echo -e "\n${YELLOW}Existing path:${NC} $dest$is_dir"
        echo "  1) Back up and replace with symlink"
        echo "  2) Overwrite (no backup)"
        echo "  3) Skip"
        if [[ -n "$is_dir" ]]; then
            log_warn "Destination is a directory. Option 2 will delete all contents."
        fi
        read -rp "$(echo -e "${YELLOW}Choice [1/2/3]: ${NC}")" choice
        case "$choice" in
            1)
                local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
                mv "$dest" "$backup"
                log_info "Backed up to: $backup"
                ;;
            2) rm -rf "$dest" ;;
            3) log_warn "Skipped: $dest"; return 0 ;;
            *) log_warn "Invalid choice — skipped: $dest"; return 0 ;;
        esac
    fi

    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    log_success "Linked: $dest → $src"
}
