#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

TARGET_USER="${SUDO_USER:-$USER}"

# ── PAM U2F Constants ──────────────────────────────────────────────────────────
U2F_KEYS_DIR="/home/${TARGET_USER}/.config/Yubico"
U2F_KEYS_FILE="${U2F_KEYS_DIR}/u2f_keys"
PAM_ORIGIN="pam://$(hostname)"
PAM_SUDO="/etc/pam.d/sudo"
PAM_SYSTEM="/etc/pam.d/system-auth"

# ── PAM U2F Helper Functions ───────────────────────────────────────────────────

_wait_for_yubikey() {
    log_info "Insert your YubiKey and press Enter when ready..."
    read -r
    local attempts=0
    while ! ykman info &>/dev/null; do
        [[ $attempts -ge 10 ]] && { log_error "YubiKey not detected. Aborting."; return 1; }
        log_warn "YubiKey not detected, retrying..."
        sleep 1
        attempts=$((attempts + 1))
    done
    log_success "YubiKey detected."
}

_key_count() {
    [[ ! -f "$U2F_KEYS_FILE" ]] && echo 0 && return
    local line
    line=$(grep "^${TARGET_USER}:" "$U2F_KEYS_FILE" 2>/dev/null || true)
    [[ -z "$line" ]] && echo 0 && return
    echo "${line#*:}" | tr ':' '\n' | grep -c '.'
}

_u2f_register() {
    install_pkg pam-u2f
    install_pkg yubikey-manager
    mkdir -p "$U2F_KEYS_DIR"
    _wait_for_yubikey
    log_info "YubiKey info: $(ykman info 2>/dev/null | grep -E 'Serial|Device type' | tr '\n' ' ')"
    log_warn "Touch your YubiKey when it blinks..."
    if [[ ! -f "$U2F_KEYS_FILE" ]] || ! grep -q "^${TARGET_USER}:" "$U2F_KEYS_FILE" 2>/dev/null; then
        pamu2fcfg -u "$TARGET_USER" -o "$PAM_ORIGIN" -i "$PAM_ORIGIN" >> "$U2F_KEYS_FILE"
        log_success "First YubiKey registered for '${TARGET_USER}'."
    else
        local new_key
        new_key=$(pamu2fcfg -n -o "$PAM_ORIGIN" -i "$PAM_ORIGIN")
        new_key="${new_key#,}"
        sed -i "s|^\\(${TARGET_USER}:.*\\)$|\\1:${new_key}|" "$U2F_KEYS_FILE"
        log_success "Additional YubiKey registered for '${TARGET_USER}'."
    fi
    chmod 600 "$U2F_KEYS_FILE"
    log_info "Total keys registered: $(_key_count)"
    log_warn "Tip: Register your backup key now before logging out."
}

_u2f_list() {
    if [[ ! -f "$U2F_KEYS_FILE" ]]; then
        log_warn "No key file found at: $U2F_KEYS_FILE"; return
    fi
    local line
    line=$(grep "^${TARGET_USER}:" "$U2F_KEYS_FILE" 2>/dev/null || true)
    if [[ -z "$line" ]]; then
        log_warn "No keys registered for user '${TARGET_USER}'."; return
    fi
    local key_data="${line#*:}" count=1
    echo "$key_data" | tr ':' '\n' | while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local kh; IFS=',' read -r kh _ _ _ <<< "$entry"
        echo "  Key ${count}: handle=$(echo "$kh" | cut -c1-32)..."
        count=$((count + 1))
    done
    echo "Total: $(_key_count) key(s) registered for '${TARGET_USER}'"
}

_u2f_remove() {
    _u2f_list
    local total; total=$(_key_count)
    [[ "$total" -eq 0 ]] && return
    read -rp "Enter key number to remove (1-${total}), or 'all': " choice
    if [[ "$choice" == "all" ]]; then
        confirm "Remove ALL keys for '${TARGET_USER}'? This will break YubiKey auth." "n" || { log_warn "Aborted."; return; }
        sed -i "/^${TARGET_USER}:/d" "$U2F_KEYS_FILE"
        log_success "All keys removed."
        return
    fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$total" ]]; then
        log_error "Invalid selection."; return 0
    fi
    local line key_data new_entries idx
    line=$(grep "^${TARGET_USER}:" "$U2F_KEYS_FILE")
    key_data="${line#*:}"
    idx=1; new_entries=""
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        [[ "$idx" -ne "$choice" ]] && new_entries="${new_entries:+${new_entries}:}${entry}"
        idx=$((idx + 1))
    done < <(echo "$key_data" | tr ':' '\n')
    if [[ -z "$new_entries" ]]; then
        sed -i "/^${TARGET_USER}:/d" "$U2F_KEYS_FILE"
        log_success "Key ${choice} removed. No remaining keys — user entry deleted."
    else
        sed -i "s|^${TARGET_USER}:.*|${TARGET_USER}:${new_entries}|" "$U2F_KEYS_FILE"
        log_success "Key ${choice} removed. $(_key_count) key(s) remaining."
    fi
}

_u2f_setup_pam() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "PAM setup requires root. Run with sudo."; return 1
    fi
    local u2f_line="auth       sufficient   pam_u2f.so cue origin=${PAM_ORIGIN}"
    log_info "This will add YubiKey as sufficient auth to: $PAM_SUDO, $PAM_SYSTEM"
    log_warn "WARNING: Test sudo in a separate terminal before closing this session."
    confirm "Proceed?" "n" || { log_warn "Aborted."; return; }
    local timestamp; timestamp=$(date +%Y%m%d%H%M%S)
    for pam_file in "$PAM_SUDO" "$PAM_SYSTEM"; do
        if grep -q 'pam_u2f.so' "$pam_file" 2>/dev/null; then
            log_warn "pam_u2f already configured in ${pam_file}, skipping."; continue
        fi
        cp "$pam_file" "${pam_file}.bak.${timestamp}"
        log_info "Backed up ${pam_file} -> ${pam_file}.bak.${timestamp}"
        sed -i "0,/^auth/{/^auth/i ${u2f_line}
}" "$pam_file"
        log_success "Configured: ${pam_file}"
    done
    log_success "PAM configuration complete."
    log_warn "IMPORTANT: Open a new terminal and test 'sudo echo ok' before closing this session."
}

cmd_pam_u2f() {
    while true; do
        log_section "PAM U2F"
        echo "  1) Register a YubiKey"
        echo "  2) List registered keys"
        echo "  3) Remove a key"
        echo "  4) Configure PAM  (requires sudo)"
        echo "  0) Back"
        read -rp "$(echo -e "${YELLOW}Choice: ${NC}")" u2f_choice
        case "$u2f_choice" in
            1) _u2f_register ;;
            2) _u2f_list ;;
            3) _u2f_remove ;;
            4) _u2f_setup_pam ;;
            0) return ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

cmd_ssh_fido2() {
    log_section "SSH FIDO2 Setup"
    install_pkg libfido2
    install_pkg openssh

    local key_name
    read -rp "$(echo -e "${YELLOW}Key filename (default: id_ed25519_sk): ${NC}")" key_name
    key_name="${key_name:-id_ed25519_sk}"
    local key_path="$HOME/.ssh/$key_name"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [[ -f "$key_path" ]]; then
        if ! confirm "Key $key_path already exists. Overwrite?" "n"; then
            log_warn "Skipped."; return
        fi
        rm -f "$key_path" "${key_path}.pub"
    fi

    log_info "Insert your YubiKey. You will be prompted to touch it..."
    ssh-keygen -t ed25519-sk -O resident -f "$key_path"
    chmod 600 "$key_path"

    log_success "Key generated: $key_path"
    echo ""
    log_info "Your public key (add this to GitHub / server authorized_keys):"
    cat "${key_path}.pub"
    echo ""
    log_info "To load the resident key on a new machine: ssh-keygen -K"

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
