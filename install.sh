#!/bin/bash
# Mango Linux Configuration - Main Installation Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ─── Legacy helpers (kept for backward compat with existing scripts) ──────────

check_permissions() {
    if [[ $1 == "root" && "$(id -u)" -ne 0 ]]; then
        log_error "This option requires root privileges. Please run with sudo."
        exit 1
    fi
}

make_executable() {
    local script_path="$1"
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
    else
        log_error "Script not found: $script_path"
        exit 1
    fi
}

# ─── Header ───────────────────────────────────────────────────────────────────

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
    echo -e "${BLUE}Arch Linux setup and configuration automation${NC}"
    echo "-----------------------------------------------------------------------"
}

# ─── Legacy script runners ────────────────────────────────────────────────────

run_system_discovery() {
    log_section "System Discovery"
    local os_type="$(uname -s)"
    if [[ "$os_type" == "Linux" ]]; then
        make_executable "$SCRIPT_DIR/scripts/determine-arch-ver/linux-os-discovery-updated.sh"
        bash "$SCRIPT_DIR/scripts/determine-arch-ver/linux-os-discovery-updated.sh"
    elif [[ "$os_type" == MINGW* ]] || [[ "$os_type" == MSYS* ]] || [[ "$os_type" == CYGWIN* ]]; then
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_DIR/scripts/determine-arch-ver/windows-os-discovery-updated.ps1"
    else
        log_error "Unsupported OS: $os_type"
    fi
}

create_bootable_usb() {
    log_section "Create Bootable USB"
    check_permissions "root"
    make_executable "$SCRIPT_DIR/scripts/bootable-usb/arch-usb-creator.sh"
    bash "$SCRIPT_DIR/scripts/bootable-usb/arch-usb-creator.sh"
}

install_arch_linux() {
    log_section "Install Arch Linux"
    check_permissions "root"
    make_executable "$SCRIPT_DIR/scripts/install/arch-install-script.sh"
    log_warn "This script must be run from the Arch Linux live environment."
    if confirm "Are you booted into the Arch live environment?"; then
        bash "$SCRIPT_DIR/scripts/install/arch-install-script.sh"
    else
        log_error "Aborted. Boot into the live environment first."
    fi
}

setup_root_ca() {
    log_section "Setup Root CA"
    make_executable "$SCRIPT_DIR/scripts/setup-root-ca/root-ca-setup.sh"
    if ! command -v ykman &>/dev/null || ! command -v openssl &>/dev/null; then
        log_warn "Required tools missing: yubikey-manager, openssl"
        if confirm "Install them now?"; then
            install_pkg yubikey-manager
            install_pkg openssl
        else
            log_error "Aborted."
            return 1
        fi
    fi
    bash "$SCRIPT_DIR/scripts/setup-root-ca/root-ca-setup.sh"
}

# ─── Module auto-discovery ────────────────────────────────────────────────────

declare -a MODULE_NAMES=()
declare -a MODULE_DESCS=()
declare -a MODULE_PATHS=()

load_modules() {
    for module_file in "$SCRIPT_DIR/modules"/*/module.sh; do
        [[ -f "$module_file" ]] || continue
        # Source in a subshell to read metadata without polluting current env
        MODULE_NAME=""
        MODULE_DESC=""
        # shellcheck disable=SC1090
        source "$module_file"
        if [[ -n "$MODULE_NAME" ]]; then
            MODULE_NAMES+=("$MODULE_NAME")
            MODULE_DESCS+=("$MODULE_DESC")
            MODULE_PATHS+=("$module_file")
        fi
    done
}

run_module() {
    local idx="$1"
    local module_file="${MODULE_PATHS[$idx]}"
    MODULE_NAME="" MODULE_DESC=""
    # shellcheck disable=SC1090
    source "$module_file"
    module_run
}

# ─── Main menu ────────────────────────────────────────────────────────────────

main() {
    load_modules

    while true; do
        display_header

        echo -e "\n${BOLD}System Setup${NC}"
        echo "  1) System Discovery  — determine appropriate Arch version"
        echo "  2) Create Bootable USB"
        echo "  3) Install Arch Linux"
        echo "  4) Setup Root CA (YubiKey)"

        if [[ ${#MODULE_NAMES[@]} -gt 0 ]]; then
            echo -e "\n${BOLD}Modules${NC}"
            local i
            for i in "${!MODULE_NAMES[@]}"; do
                local num=$(( i + 5 ))
                printf "  %d) %-20s — %s\n" "$num" "${MODULE_NAMES[$i]}" "${MODULE_DESCS[$i]}"
            done
        fi

        echo ""
        echo "  0) Exit"
        echo ""
        read -rp "$(echo -e "${YELLOW}Choice: ${NC}")" choice

        case "$choice" in
            1) run_system_discovery ;;
            2) create_bootable_usb ;;
            3) install_arch_linux ;;
            4) setup_root_ca ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *)
                local module_idx=$(( choice - 5 ))
                if [[ $module_idx -ge 0 && $module_idx -lt ${#MODULE_NAMES[@]} ]]; then
                    run_module "$module_idx"
                else
                    log_error "Invalid choice."
                fi
                ;;
        esac

        echo ""
        confirm "Return to main menu?" "y" || { echo -e "${GREEN}Goodbye!${NC}"; exit 0; }
    done
}

main
