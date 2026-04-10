#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

BW_SESSION=""

cleanup() {
    if [[ -n "$BW_SESSION" ]]; then
        bw lock --session "$BW_SESSION" &>/dev/null || true
        BW_SESSION=""
    fi
    unset BW_SESSION
}
trap cleanup EXIT INT TERM

cmd_install() {
    install_pkg bitwarden-cli aur
}

cmd_login() {
    log_section "Bitwarden Login"

    # Check current status — if already unlocked, reuse session
    local status=""
    status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || true)

    if [[ "$status" == "unauthenticated" || -z "$status" ]]; then
        local email=""
        read -rp "$(echo -e "${YELLOW}Bitwarden email: ${NC}")" email

        local use_otp="n"
        if confirm "Use YubiKey OTP for 2FA? (requires YubiKey OTP configured in Bitwarden)" "n"; then
            use_otp="y"
        fi

        if [[ "$use_otp" == "y" ]]; then
            log_info "You will be prompted for your password, then touch your YubiKey for the OTP."
            BW_SESSION=$(bw login "$email" --method 3 --raw)
        else
            BW_SESSION=$(bw login "$email" --raw)
        fi
    else
        # Already logged in (locked or unlocked) — just unlock
        log_info "Already logged in. Unlocking vault..."
        BW_SESSION=$(bw unlock --raw)
    fi

    if [[ -z "$BW_SESSION" ]]; then
        log_error "Failed to authenticate with Bitwarden."
        exit 1
    fi

    log_success "Bitwarden unlocked."
}

show_pull_menu(){ log_warn "Pull menu: not yet implemented"; }

cmd_install
cmd_login
show_pull_menu
