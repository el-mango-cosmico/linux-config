#!/bin/bash

# YubiKey PAM Authentication Setup
# Registers YubiKeys as authentication for this machine via pam-u2f.
#
# Usage:
#   ./yubikey-auth-setup.sh             # interactive menu
#   ./yubikey-auth-setup.sh register    # register a new key
#   ./yubikey-auth-setup.sh list        # list registered keys
#   ./yubikey-auth-setup.sh remove      # remove a key
#   ./yubikey-auth-setup.sh setup-pam   # configure PAM (run as root)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Config ────────────────────────────────────────────────────────────────────

TARGET_USER="${SUDO_USER:-$USER}"
U2F_KEYS_DIR="/home/${TARGET_USER}/.config/Yubico"
U2F_KEYS_FILE="${U2F_KEYS_DIR}/u2f_keys"
PAM_ORIGIN="pam://$(hostname)"

# PAM files to configure (sudo gets YubiKey, system-auth handles login/su)
PAM_SUDO="/etc/pam.d/sudo"
PAM_SYSTEM="/etc/pam.d/system-auth"
PAM_U2F_LINE="auth       sufficient   pam_u2f.so cue origin=${PAM_ORIGIN}"

# ── Helpers ───────────────────────────────────────────────────────────────────

require_command() {
    if ! command -v "$1" &>/dev/null; then
        echo -e "${RED}Required command not found: $1${NC}"
        echo -e "${YELLOW}Install with: sudo pacman -S $2${NC}"
        exit 1
    fi
}

check_dependencies() {
    require_command pamu2fcfg pam-u2f
    require_command ykman yubikey-manager
}

wait_for_yubikey() {
    echo -e "${YELLOW}Insert your YubiKey and press Enter when ready...${NC}"
    read -r
    local attempts=0
    while ! ykman info &>/dev/null; do
        if [[ $attempts -ge 10 ]]; then
            echo -e "${RED}YubiKey not detected after waiting. Aborting.${NC}"
            exit 1
        fi
        echo -e "${YELLOW}YubiKey not detected, retrying...${NC}"
        sleep 1
        attempts=$((attempts + 1))
    done
    echo -e "${GREEN}YubiKey detected.${NC}"
}

show_key_info() {
    echo -e "${CYAN}YubiKey info:${NC}"
    ykman info 2>/dev/null | grep -E 'Serial|Device type' | sed 's/^/  /'
}

key_count() {
    if [[ ! -f "$U2F_KEYS_FILE" ]]; then
        echo 0
        return
    fi
    local line
    line=$(grep "^${TARGET_USER}:" "$U2F_KEYS_FILE" 2>/dev/null || true)
    if [[ -z "$line" ]]; then
        echo 0
        return
    fi
    # Keys are separated by colons after the username; each key is a comma-separated tuple
    # Format: user:kh,pk,type,opts:kh,pk,type,opts:...
    local key_data="${line#*:}"
    echo "$key_data" | tr ':' '\n' | grep -c '.'
}

# ── Register ──────────────────────────────────────────────────────────────────

cmd_register() {
    check_dependencies
    mkdir -p "$U2F_KEYS_DIR"

    echo -e "\n${BLUE}=== Register YubiKey ===${NC}"
    wait_for_yubikey
    show_key_info

    echo -e "\n${YELLOW}Touch your YubiKey when it blinks...${NC}"

    if [[ ! -f "$U2F_KEYS_FILE" ]] || ! grep -q "^${TARGET_USER}:" "$U2F_KEYS_FILE" 2>/dev/null; then
        # First key — write the full line
        pamu2fcfg -u "$TARGET_USER" -o "$PAM_ORIGIN" -i "$PAM_ORIGIN" >> "$U2F_KEYS_FILE"
        echo -e "\n${GREEN}First YubiKey registered for user '${TARGET_USER}'.${NC}"
    else
        # Additional key — append to existing line
        local new_key
        new_key=$(pamu2fcfg -n -o "$PAM_ORIGIN" -i "$PAM_ORIGIN")
        # Strip leading comma if present
        new_key="${new_key#,}"
        # Append as a new colon-separated key entry on the existing line
        sed -i "s/^\\(${TARGET_USER}:.*\\)$/\\1:${new_key}/" "$U2F_KEYS_FILE"
        echo -e "\n${GREEN}Additional YubiKey registered for user '${TARGET_USER}'.${NC}"
    fi

    chmod 600 "$U2F_KEYS_FILE"
    echo -e "Total keys registered: $(key_count)"
    echo -e "${YELLOW}Tip: Register your backup key now before logging out.${NC}"
}

# ── List ──────────────────────────────────────────────────────────────────────

cmd_list() {
    echo -e "\n${BLUE}=== Registered YubiKeys ===${NC}"
    if [[ ! -f "$U2F_KEYS_FILE" ]]; then
        echo -e "${YELLOW}No key file found at: $U2F_KEYS_FILE${NC}"
        return
    fi

    local line
    line=$(grep "^${TARGET_USER}:" "$U2F_KEYS_FILE" 2>/dev/null || true)
    if [[ -z "$line" ]]; then
        echo -e "${YELLOW}No keys registered for user '${TARGET_USER}'.${NC}"
        return
    fi

    local key_data="${line#*:}"
    local count=1
    echo "$key_data" | tr ':' '\n' | while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        local kh pk type opts
        IFS=',' read -r kh pk type opts <<< "$entry"
        echo -e "  Key ${count}: type=${type:-es256} ${opts:+opts=$opts}"
        echo -e "          handle=$(echo "$kh" | cut -c1-32)..."
        count=$((count + 1))
    done

    echo -e "\nTotal: $(key_count) key(s) registered for '${TARGET_USER}'"
}

# ── Remove ────────────────────────────────────────────────────────────────────

cmd_remove() {
    echo -e "\n${BLUE}=== Remove YubiKey ===${NC}"
    cmd_list

    local total
    total=$(key_count)
    if [[ "$total" -eq 0 ]]; then
        return
    fi

    read -rp "Enter key number to remove (1-${total}), or 'all' to clear: " choice

    if [[ "$choice" == "all" ]]; then
        read -rp "Remove ALL keys for '${TARGET_USER}'? This will break YubiKey auth. (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            sed -i "/^${TARGET_USER}:/d" "$U2F_KEYS_FILE"
            echo -e "${GREEN}All keys removed.${NC}"
        else
            echo -e "${YELLOW}Aborted.${NC}"
        fi
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$total" ]]; then
        echo -e "${RED}Invalid selection.${NC}"
        exit 1
    fi

    local line key_data entries new_entries idx new_line
    line=$(grep "^${TARGET_USER}:" "$U2F_KEYS_FILE")
    key_data="${line#*:}"

    # Rebuild the key list without the chosen entry
    idx=1
    new_entries=""
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        if [[ "$idx" -ne "$choice" ]]; then
            new_entries="${new_entries:+${new_entries}:}${entry}"
        fi
        idx=$((idx + 1))
    done < <(echo "$key_data" | tr ':' '\n')

    if [[ -z "$new_entries" ]]; then
        sed -i "/^${TARGET_USER}:/d" "$U2F_KEYS_FILE"
        echo -e "${GREEN}Key ${choice} removed. No remaining keys — user entry deleted.${NC}"
    else
        new_line="${TARGET_USER}:${new_entries}"
        sed -i "s|^${TARGET_USER}:.*|${new_line}|" "$U2F_KEYS_FILE"
        echo -e "${GREEN}Key ${choice} removed. $(key_count) key(s) remaining.${NC}"
    fi
}

# ── PAM Setup ─────────────────────────────────────────────────────────────────

cmd_setup_pam() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${RED}PAM setup requires root. Run with sudo.${NC}"
        exit 1
    fi

    echo -e "\n${BLUE}=== Configure PAM for YubiKey Auth ===${NC}"
    echo -e "Origin: ${CYAN}${PAM_ORIGIN}${NC}"
    echo -e "\nThis will add YubiKey as ${YELLOW}sufficient${NC} auth to:"
    echo -e "  - ${PAM_SUDO}  (sudo)"
    echo -e "  - ${PAM_SYSTEM}  (login / su / lock screen)"
    echo -e "\n${YELLOW}WARNING: Test sudo in a separate terminal before closing this session.${NC}"
    read -rp "Proceed? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Aborted.${NC}"
        exit 0
    fi

    local u2f_line="auth       sufficient   pam_u2f.so cue origin=${PAM_ORIGIN}"
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)

    for pam_file in "$PAM_SUDO" "$PAM_SYSTEM"; do
        if grep -q 'pam_u2f.so' "$pam_file" 2>/dev/null; then
            echo -e "${YELLOW}pam_u2f already configured in ${pam_file}, skipping.${NC}"
            continue
        fi

        cp "$pam_file" "${pam_file}.bak.${timestamp}"
        echo -e "${CYAN}Backed up ${pam_file} -> ${pam_file}.bak.${timestamp}${NC}"

        # Insert u2f line as first auth line
        sed -i "0,/^auth/{/^auth/i ${u2f_line}
}" "$pam_file"
        echo -e "${GREEN}Configured: ${pam_file}${NC}"
    done

    echo -e "\n${GREEN}PAM configuration complete.${NC}"
    echo -e "${YELLOW}IMPORTANT: Open a new terminal and test 'sudo echo ok' before closing this session.${NC}"
    echo -e "To revert, restore the .bak files in /etc/pam.d/"
}

# ── Menu ──────────────────────────────────────────────────────────────────────

show_menu() {
    echo -e "\n${GREEN}=== YubiKey Authentication Setup ===${NC}"
    echo -e "  User       : ${TARGET_USER}"
    echo -e "  Keys file  : ${U2F_KEYS_FILE}"
    echo -e "  PAM origin : ${PAM_ORIGIN}"
    echo -e "  Registered : $(key_count) key(s)\n"
    echo -e "1) Register a YubiKey"
    echo -e "2) List registered keys"
    echo -e "3) Remove a key"
    echo -e "4) Configure PAM  (requires sudo)"
    echo -e "0) Exit"
    read -rp "Choice: " choice
    case "$choice" in
        1) cmd_register ;;
        2) cmd_list ;;
        3) cmd_remove ;;
        4) cmd_setup_pam ;;
        0) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}"; show_menu ;;
    esac
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

case "${1:-menu}" in
    register)   cmd_register ;;
    list)       cmd_list ;;
    remove)     cmd_remove ;;
    setup-pam)  cmd_setup_pam ;;
    menu)       show_menu ;;
    *)
        echo "Usage: $0 [register|list|remove|setup-pam]"
        exit 1
        ;;
esac
