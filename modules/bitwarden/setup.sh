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

_status_bw_installed() {
    if pacman -Qq bitwarden-cli &>/dev/null 2>&1; then
        echo "[✓ installed]"
    else
        echo "[✗ not installed]"
    fi
}

_status_bw_auth() {
    if ! command -v bw &>/dev/null; then
        echo "[? bw not installed]"; return
    fi
    local s=""
    s=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || true)
    case "$s" in
        unlocked)        echo "[✓ unlocked]" ;;
        locked)          echo "[~ locked]" ;;
        *)               echo "[✗ not logged in]" ;;
    esac
}

show_status_summary() {
    log_section "Bitwarden Status"
    local s_installed s_auth
    s_installed=$(_status_bw_installed)
    s_auth=$(_status_bw_auth)
    echo "  CLI installed:  ${s_installed}"
    echo "  Vault auth:     ${s_auth}"
    echo ""
}

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
            BW_SESSION=$(bw login "$email" --method 3 --raw) || true
        else
            BW_SESSION=$(bw login "$email" --raw) || true
        fi
    else
        # Already logged in (locked or unlocked) — just unlock
        log_info "Already logged in. Unlocking vault..."
        BW_SESSION=$(bw unlock --raw) || true
    fi

    if [[ -z "$BW_SESSION" ]]; then
        log_error "Failed to authenticate with Bitwarden."
        exit 1
    fi

    log_success "Bitwarden unlocked."
}

_pull_ssh_key() {
    local item_name=""
    read -rp "$(echo -e "${YELLOW}Bitwarden item name: ${NC}")" item_name

    local key_content=""
    key_content=$(bw get notes "$item_name" --session "$BW_SESSION" 2>/dev/null || true)

    if [[ -z "$key_content" ]]; then
        log_error "Item '$item_name' not found or has no notes content in Bitwarden."
        return 0
    fi

    local filename=""
    read -rp "$(echo -e "${YELLOW}Save as ~/.ssh/: ${NC}")" filename
    if [[ -z "$filename" ]]; then
        log_error "Filename cannot be empty."
        return 0
    fi
    local key_path="$HOME/.ssh/$filename"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    printf '%s\n' "$key_content" > "$key_path"
    chmod 600 "$key_path"
    log_success "SSH key saved to $key_path"

    if confirm "Add IdentityFile entry to ~/.ssh/config?" "n"; then
        local config="$HOME/.ssh/config"
        touch "$config"
        chmod 600 "$config"
        if ! grep -qF "IdentityFile $key_path" "$config" 2>/dev/null; then
            printf '\nHost *\n    IdentityFile %s\n' "$key_path" >> "$config"
            log_success "Added to ~/.ssh/config"
        else
            log_info "Already present in ~/.ssh/config"
        fi
    fi
}

_pull_env_file() {
    local item_name=""
    read -rp "$(echo -e "${YELLOW}Bitwarden item name: ${NC}")" item_name

    local notes=""
    notes=$(bw get notes "$item_name" --session "$BW_SESSION" 2>/dev/null || true)

    if [[ -z "$notes" ]]; then
        log_error "Item '$item_name' not found or has no notes content in Bitwarden."
        return 0
    fi

    local dest_path=""
    read -rp "$(echo -e "${YELLOW}Save to path (e.g. ~/.env): ${NC}")" dest_path
    dest_path="${dest_path/#\~/$HOME}"
    if [[ -z "$dest_path" ]]; then
        log_error "Destination path cannot be empty."
        return 0
    fi

    mkdir -p "$(dirname "$dest_path")"
    printf '%s\n' "$notes" > "$dest_path"
    chmod 600 "$dest_path"
    log_success "Environment file saved to $dest_path"
}

show_pull_menu() {
    while true; do
        log_section "Pull Secrets from Bitwarden"
        echo "  1) SSH private key"
        echo "  2) Environment file (secure note)"
        echo "  0) Done"
        local choice=""
        read -rp "$(echo -e "${YELLOW}Choice: ${NC}")" choice || true
        case "$choice" in
            1) _pull_ssh_key ;;
            2) _pull_env_file ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

show_status_summary
cmd_install
cmd_login
show_pull_menu
