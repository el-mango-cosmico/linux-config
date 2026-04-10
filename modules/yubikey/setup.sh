#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

TARGET_USER="${SUDO_USER:-$USER}"

cmd_pam_u2f()  { log_warn "PAM U2F: not yet implemented"; }
cmd_ssh_fido2(){ log_warn "SSH FIDO2: not yet implemented"; }
cmd_gpg()      { log_warn "GPG: not yet implemented"; }

show_menu() {
    while true; do
        log_section "YubiKey Setup"
        echo "  1) PAM U2F      — register YubiKey for sudo / login"
        echo "  2) SSH FIDO2    — generate resident FIDO2 SSH key"
        echo "  3) GPG          — configure OpenPGP card + git signing"
        echo "  0) Exit"
        read -rp "$(echo -e "${YELLOW}Choice: ${NC}")" choice
        case "$choice" in
            1) cmd_pam_u2f ;;
            2) cmd_ssh_fido2 ;;
            3) cmd_gpg ;;
            0) exit 0 ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

show_menu
