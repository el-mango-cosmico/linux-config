# YubiKey + Bitwarden Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two auto-discovered modules — `modules/yubikey/` (PAM U2F, SSH FIDO2, GPG signing) and `modules/bitwarden/` (install bw CLI, unlock with YubiKey OTP 2FA, pull SSH keys + env files).

**Architecture:** Each module follows the existing pattern: thin `module.sh` with metadata + `module_run()`, and a `setup.sh` with the real logic. Both source `lib/common.sh` for logging, confirmation, and package installation helpers. The YubiKey module migrates and extends the existing `scripts/yubikey-auth/yubikey-auth-setup.sh`. The Bitwarden module is new.

**Tech Stack:** bash, pam-u2f, yubikey-manager, libfido2, openssh, gnupg, pinentry, bitwarden-cli (AUR), bw CLI

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `modules/yubikey/module.sh` | Module metadata + entry point |
| Create | `modules/yubikey/setup.sh` | PAM U2F + SSH FIDO2 + GPG menu |
| Create | `modules/bitwarden/module.sh` | Module metadata + entry point |
| Create | `modules/bitwarden/setup.sh` | Install + login + secrets pull |
| Modify | `MODULES.md` | Add both modules to the table |

The existing `scripts/yubikey-auth/yubikey-auth-setup.sh` is **kept as-is** (it still works standalone). Its logic is duplicated into the new module; the standalone script is not deleted.

---

## Task 1: YubiKey module scaffold + menu skeleton

**Files:**
- Create: `modules/yubikey/module.sh`
- Create: `modules/yubikey/setup.sh`

- [ ] **Step 1: Create `modules/yubikey/module.sh`**

```bash
#!/bin/bash
MODULE_NAME="yubikey"
MODULE_DESC="YubiKey setup: PAM U2F, SSH FIDO2, GPG signing"

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
}
```

- [ ] **Step 2: Create `modules/yubikey/setup.sh` with menu skeleton**

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

TARGET_USER="${SUDO_USER:-$USER}"

cmd_pam_u2f()  { log_warn "PAM U2F: not yet implemented"; }
cmd_ssh_fido2(){ log_warn "SSH FIDO2: not yet implemented"; }
cmd_gpg()      { log_warn "GPG: not yet implemented"; }

show_menu() {
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
        *) log_error "Invalid option"; show_menu ;;
    esac
}

show_menu
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n modules/yubikey/module.sh
bash -n modules/yubikey/setup.sh
```

Expected: no output (clean).

- [ ] **Step 4: Verify auto-discovery**

```bash
bash -c 'source lib/common.sh; for f in modules/*/module.sh; do source "$f"; echo "$MODULE_NAME — $MODULE_DESC"; done'
```

Expected output includes:
```
yubikey — YubiKey setup: PAM U2F, SSH FIDO2, GPG signing
```

- [ ] **Step 5: Commit**

```bash
git add modules/yubikey/module.sh modules/yubikey/setup.sh
git commit -m "feat(yubikey): add module scaffold with menu skeleton"
```

---

## Task 2: Implement PAM U2F sub-flow

**Files:**
- Modify: `modules/yubikey/setup.sh` (replace `cmd_pam_u2f` stub)

The logic mirrors `scripts/yubikey-auth/yubikey-auth-setup.sh` but uses `lib/common.sh` helpers and keeps everything inside `cmd_pam_u2f`.

- [ ] **Step 1: Replace `cmd_pam_u2f` stub in `modules/yubikey/setup.sh`**

Replace the line `cmd_pam_u2f()  { log_warn "PAM U2F: not yet implemented"; }` with:

```bash
# ── PAM U2F ───────────────────────────────────────────────────────────────────

U2F_KEYS_DIR="/home/${TARGET_USER}/.config/Yubico"
U2F_KEYS_FILE="${U2F_KEYS_DIR}/u2f_keys"
PAM_ORIGIN="pam://$(hostname)"
PAM_SUDO="/etc/pam.d/sudo"
PAM_SYSTEM="/etc/pam.d/system-auth"

_wait_for_yubikey() {
    log_info "Insert your YubiKey and press Enter when ready..."
    read -r
    local attempts=0
    while ! ykman info &>/dev/null; do
        [[ $attempts -ge 10 ]] && { log_error "YubiKey not detected. Aborting."; exit 1; }
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
        sed -i "s/^\\(${TARGET_USER}:.*\\)$/\\1:${new_key}/" "$U2F_KEYS_FILE"
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
        log_error "Invalid selection."; return 1
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
    confirm "Proceed?" || { log_warn "Aborted."; return; }
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
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n modules/yubikey/setup.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/yubikey/setup.sh
git commit -m "feat(yubikey): implement PAM U2F sub-flow"
```

---

## Task 3: Implement SSH FIDO2 sub-flow

**Files:**
- Modify: `modules/yubikey/setup.sh` (replace `cmd_ssh_fido2` stub)

- [ ] **Step 1: Replace `cmd_ssh_fido2` stub in `modules/yubikey/setup.sh`**

Replace the line `cmd_ssh_fido2(){ log_warn "SSH FIDO2: not yet implemented"; }` with:

```bash
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

    if confirm "Add IdentityFile entry to ~/.ssh/config?"; then
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
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n modules/yubikey/setup.sh
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add modules/yubikey/setup.sh
git commit -m "feat(yubikey): implement SSH FIDO2 sub-flow"
```

---

## Task 4: Implement GPG sub-flow

**Files:**
- Modify: `modules/yubikey/setup.sh` (replace `cmd_gpg` stub)

- [ ] **Step 1: Replace `cmd_gpg` stub in `modules/yubikey/setup.sh`**

Replace the line `cmd_gpg()      { log_warn "GPG: not yet implemented"; }` with:

```bash
cmd_gpg() {
    log_section "GPG / Git Signing Setup"
    install_pkg gnupg
    install_pkg yubikey-manager
    install_pkg pinentry

    log_info "Checking for YubiKey OpenPGP card..."
    if ! gpg --card-status &>/dev/null; then
        log_error "No OpenPGP card detected. Insert your YubiKey and ensure the OpenPGP applet is enabled."
        return 1
    fi

    gpg --card-status

    # Check if a signing key is already on the card
    local sig_line
    sig_line=$(gpg --card-status 2>/dev/null | grep "^Signature key" || true)
    if echo "$sig_line" | grep -q "\[none\]"; then
        log_warn "No signing key found on YubiKey."
        echo "  1) Generate a new key on the card (interactive)"
        echo "  2) Import an existing key from a file"
        echo "  0) Cancel"
        read -rp "$(echo -e "${YELLOW}Choice: ${NC}")" gpg_choice
        case "$gpg_choice" in
            1)
                log_info "Opening gpg card editor."
                log_info "Type 'generate' and follow the prompts. Type 'quit' when done."
                gpg --card-edit
                ;;
            2)
                read -rp "$(echo -e "${YELLOW}Path to key file: ${NC}")" key_file
                gpg --import "$key_file"
                log_info "Now move the key to the card with: gpg --edit-key <KEY_ID> then 'keytocard'"
                gpg --card-edit
                ;;
            0) return ;;
            *) log_error "Invalid option"; return 1 ;;
        esac
    fi

    # Re-read after any changes
    local key_id
    key_id=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
        | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)

    if [[ -z "$key_id" ]]; then
        log_error "Could not determine key ID. Configure git signing manually with: git config --global user.signingkey <KEY_ID>"
        return 1
    fi

    git config --global user.signingkey "$key_id"
    git config --global commit.gpgsign true
    git config --global gpg.program gpg

    log_success "Git configured to sign commits with key: $key_id"
    echo ""
    log_info "Export and upload your public key to GitHub:"
    echo "    gpg --armor --export $key_id"
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n modules/yubikey/setup.sh
```

Expected: no output.

- [ ] **Step 3: Verify the full yubikey module runs without errors (no YubiKey needed for menu display)**

```bash
echo "0" | bash modules/yubikey/setup.sh
```

Expected: menu is displayed and exits cleanly on input "0".

- [ ] **Step 4: Commit**

```bash
git add modules/yubikey/setup.sh
git commit -m "feat(yubikey): implement GPG / git signing sub-flow"
```

---

## Task 5: Bitwarden module scaffold

**Files:**
- Create: `modules/bitwarden/module.sh`
- Create: `modules/bitwarden/setup.sh`

- [ ] **Step 1: Create `modules/bitwarden/module.sh`**

```bash
#!/bin/bash
MODULE_NAME="bitwarden"
MODULE_DESC="Bitwarden CLI setup: install, unlock, pull SSH keys + env files"

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
}
```

- [ ] **Step 2: Create `modules/bitwarden/setup.sh` skeleton**

```bash
#!/bin/bash
set -e

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

cmd_install()  { log_warn "Install: not yet implemented"; }
cmd_login()    { log_warn "Login: not yet implemented"; }
show_pull_menu(){ log_warn "Pull menu: not yet implemented"; }

cmd_install
cmd_login
show_pull_menu
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n modules/bitwarden/module.sh
bash -n modules/bitwarden/setup.sh
```

Expected: no output.

- [ ] **Step 4: Verify auto-discovery includes bitwarden**

```bash
bash -c 'source lib/common.sh; for f in modules/*/module.sh; do source "$f"; echo "$MODULE_NAME — $MODULE_DESC"; done'
```

Expected output includes both:
```
yubikey — YubiKey setup: PAM U2F, SSH FIDO2, GPG signing
bitwarden — Bitwarden CLI setup: install, unlock, pull SSH keys + env files
```

- [ ] **Step 5: Commit**

```bash
git add modules/bitwarden/module.sh modules/bitwarden/setup.sh
git commit -m "feat(bitwarden): add module scaffold"
```

---

## Task 6: Implement Bitwarden install + login flow

**Files:**
- Modify: `modules/bitwarden/setup.sh` (replace `cmd_install` and `cmd_login` stubs)

- [ ] **Step 1: Replace `cmd_install` stub in `modules/bitwarden/setup.sh`**

Replace `cmd_install()  { log_warn "Install: not yet implemented"; }` with:

```bash
cmd_install() {
    install_pkg bitwarden-cli aur
}
```

- [ ] **Step 2: Replace `cmd_login` stub in `modules/bitwarden/setup.sh`**

Replace `cmd_login()    { log_warn "Login: not yet implemented"; }` with:

```bash
cmd_login() {
    log_section "Bitwarden Login"

    # Check current status — if already unlocked, reuse session
    local status
    status=$(bw status 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || true)

    if [[ "$status" == "unlocked" ]]; then
        log_info "Bitwarden is already unlocked. Re-unlocking to get a fresh session..."
    fi

    local email
    if [[ "$status" == "unauthenticated" || -z "$status" ]]; then
        read -rp "$(echo -e "${YELLOW}Bitwarden email: ${NC}")" email
    fi

    local use_otp="n"
    if confirm "Use YubiKey OTP for 2FA? (requires YubiKey OTP configured in Bitwarden)" "n"; then
        use_otp="y"
    fi

    if [[ "$status" == "unauthenticated" || -z "$status" ]]; then
        # Need to log in from scratch
        if [[ "$use_otp" == "y" ]]; then
            log_info "You will be prompted for your password, then touch your YubiKey for the OTP."
            BW_SESSION=$(bw login "$email" --method 3 --raw)
        else
            BW_SESSION=$(bw login "$email" --raw)
        fi
    else
        # Already logged in (locked or unlocked) — just unlock
        BW_SESSION=$(bw unlock --raw)
    fi

    if [[ -z "$BW_SESSION" ]]; then
        log_error "Failed to authenticate with Bitwarden."
        exit 1
    fi

    log_success "Bitwarden unlocked."
}
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n modules/bitwarden/setup.sh
```

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add modules/bitwarden/setup.sh
git commit -m "feat(bitwarden): implement install + login flow with YubiKey OTP support"
```

---

## Task 7: Implement secrets pull menu

**Files:**
- Modify: `modules/bitwarden/setup.sh` (replace `show_pull_menu` stub)

- [ ] **Step 1: Replace `show_pull_menu` stub in `modules/bitwarden/setup.sh`**

Replace `show_pull_menu(){ log_warn "Pull menu: not yet implemented"; }` with:

```bash
_pull_ssh_key() {
    local item_name
    read -rp "$(echo -e "${YELLOW}Bitwarden item name: ${NC}")" item_name

    local key_content
    key_content=$(bw get notes "$item_name" --session "$BW_SESSION" 2>/dev/null || true)

    if [[ -z "$key_content" ]]; then
        log_error "Item '$item_name' not found or has no notes content in Bitwarden."
        return 1
    fi

    local filename
    read -rp "$(echo -e "${YELLOW}Save as ~/.ssh/: ${NC}")" filename
    local key_path="$HOME/.ssh/$filename"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    printf '%s\n' "$key_content" > "$key_path"
    chmod 600 "$key_path"
    log_success "SSH key saved to $key_path"

    if confirm "Add IdentityFile entry to ~/.ssh/config?"; then
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
    local item_name
    read -rp "$(echo -e "${YELLOW}Bitwarden item name: ${NC}")" item_name

    local notes
    notes=$(bw get notes "$item_name" --session "$BW_SESSION" 2>/dev/null || true)

    if [[ -z "$notes" ]]; then
        log_error "Item '$item_name' not found or has no notes content in Bitwarden."
        return 1
    fi

    local dest_path
    read -rp "$(echo -e "${YELLOW}Save to path (e.g. ~/.env): ${NC}")" dest_path
    dest_path="${dest_path/#\~/$HOME}"

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
        read -rp "$(echo -e "${YELLOW}Choice: ${NC}")" choice
        case "$choice" in
            1) _pull_ssh_key ;;
            2) _pull_env_file ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n modules/bitwarden/setup.sh
```

Expected: no output.

- [ ] **Step 3: Verify cleanup trap is wired correctly**

Grep for the trap to confirm it's still at the top:

```bash
grep "trap cleanup" modules/bitwarden/setup.sh
```

Expected:
```
trap cleanup EXIT INT TERM
```

- [ ] **Step 4: Commit**

```bash
git add modules/bitwarden/setup.sh
git commit -m "feat(bitwarden): implement SSH key + env file secrets pull"
```

---

## Task 8: Update MODULES.md

**Files:**
- Modify: `MODULES.md`

- [ ] **Step 1: Add both new modules to the table in `MODULES.md`**

Find the existing table:
```
| `dotfiles` | Shell, git, and prompt config |
| `nvim` | Neovim with LazyVim, LSPs, and AI |
| `kde` | KDE Plasma backup and restore |
```

Replace it with:
```
| `dotfiles` | Shell, git, and prompt config |
| `nvim` | Neovim with LazyVim, LSPs, and AI |
| `kde` | KDE Plasma backup and restore |
| `yubikey` | PAM U2F, SSH FIDO2, GPG / git signing |
| `bitwarden` | Install bw CLI, unlock with YubiKey OTP, pull SSH keys + env files |
```

- [ ] **Step 2: Commit**

```bash
git add MODULES.md
git commit -m "docs: add yubikey and bitwarden modules to MODULES.md"
```

---

## Self-Review Notes

- **Spec coverage:** PAM U2F ✓, SSH FIDO2 ✓, GPG signing ✓, Bitwarden install ✓, YubiKey OTP 2FA ✓, SSH key pull ✓, env file pull ✓, session cleanup ✓, MODULES.md ✓
- **No placeholders:** All stubs are replaced with real code before commit
- **Type/name consistency:** `BW_SESSION` used consistently; `_u2f_*` helpers prefixed to avoid collisions; `cleanup` trap references `BW_SESSION` correctly
- **Security:** Passwords never passed as CLI args — `bw login` handles its own prompts; `chmod 600` on all written key/env files; `BW_SESSION` unset in `cleanup` trap
- **Standalone runnable:** Both `setup.sh` files can be run directly via `bash modules/<name>/setup.sh`
