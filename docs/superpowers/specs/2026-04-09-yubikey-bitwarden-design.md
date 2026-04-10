# YubiKey + Bitwarden Module Design

**Date:** 2026-04-09  
**Status:** Approved

## Overview

Add two new modules to the linux-config module system:

1. `modules/yubikey/` — full YubiKey setup: PAM U2F, SSH FIDO2, GPG/git signing
2. `modules/bitwarden/` — Bitwarden CLI install + one-time secrets pull, with YubiKey OTP 2FA support

Both modules auto-discover into the `install.sh` menu and follow existing module conventions.

---

## Module: yubikey

### Location

```
modules/yubikey/
├── module.sh      # MODULE_NAME, MODULE_DESC, module_run()
└── setup.sh       # menu + sub-command logic
```

The existing `scripts/yubikey-auth/yubikey-auth-setup.sh` is refactored into this module. Its PAM U2F logic becomes one of three sub-flows.

### Menu Structure

Running `bash modules/yubikey/setup.sh` (or via `install.sh`) presents:

```
1) PAM U2F      — register YubiKey for sudo / login
2) SSH FIDO2    — generate resident FIDO2 SSH key
3) GPG          — configure OpenPGP card + git signing
0) Exit
```

Each option is independent and idempotent where possible.

### Sub-flow: PAM U2F

Refactored from `scripts/yubikey-auth/yubikey-auth-setup.sh`. Behaviour unchanged:

- `register` — run `pamu2fcfg`, append to `~/.config/Yubico/u2f_keys`
- `list` — parse and display registered key handles
- `remove` — remove a specific key by index, or all keys
- `setup-pam` — insert `pam_u2f.so sufficient` into `/etc/pam.d/sudo` and `/etc/pam.d/system-auth` (requires root, backs up originals)

Dependencies: `pam-u2f`, `yubikey-manager`

### Sub-flow: SSH FIDO2

1. Check `libfido2` and `openssh >= 8.2` are present; install if missing
2. Prompt for key name (default: `id_ed25519_sk`)
3. Run: `ssh-keygen -t ed25519-sk -O resident -f ~/.ssh/<name>`  
   — resident key is stored on YubiKey hardware, discoverable via `ssh-keygen -K`
4. Display the public key and remind user to add it to GitHub / authorized_keys
5. Append a `~/.ssh/config` Host block if the user confirms:
   ```
   Host *
       IdentityFile ~/.ssh/<name>
   ```

Dependencies: `libfido2`, `openssh`

### Sub-flow: GPG / Git Signing

1. Check `gnupg` and `yubikey-manager` are present
2. Run `gpg --card-status` to confirm the YubiKey OpenPGP card is detected
3. If no key is on the card: prompt the user — they can either:
   - Generate a new key on the card (`gpg --card-edit` → `generate`)
   - Import an existing key from a file or keyserver
4. Once a key is present: read the key ID from `gpg --card-status`
5. Configure git globals:
   ```
   git config --global user.signingkey <KEY_ID>
   git config --global commit.gpgsign true
   git config --global gpg.program gpg
   ```
6. Remind user to export and upload their public key to GitHub if not already done

Dependencies: `gnupg`, `yubikey-manager`, `pinentry`

---

## Module: bitwarden

### Location

```
modules/bitwarden/
├── module.sh      # MODULE_NAME, MODULE_DESC, module_run()
└── setup.sh       # install + unlock + secrets pull
```

### Flow

#### 1. Install

Install `bitwarden-cli` from AUR using `install_pkg bitwarden-cli aur`. Skip if already installed.

#### 2. Login + Unlock

```
Enter Bitwarden email: _
Enter master password: _
Use YubiKey OTP for 2FA? [Y/n]: _
```

- If YubiKey OTP selected: run `bw login <email> --method 3 --code <otp>`  
  — the script prompts "Touch your YubiKey..." and reads the OTP from stdin (user touches key, OTP is typed automatically)
- If no YubiKey OTP: run `bw login <email>` with password only
- On success, capture the session token (`BW_SESSION`) into a local variable — **never written to disk**
- Export `BW_SESSION` into the current shell environment for subsequent `bw` calls

#### 3. Secrets Pull Menu

```
What do you want to pull?
1) SSH private key
2) Environment file (secure note)
0) Done
```

Repeats until user selects 0.

**SSH private key:**
1. Prompt: `Bitwarden item name: _`
2. Run `bw get item <name> --session $BW_SESSION`
3. Extract the private key field (expects a "SSH Private Key" custom field or the notes field)
4. Prompt: `Save as ~/.ssh/<filename>: _`
5. Write to `~/.ssh/<filename>`, `chmod 600`
6. Optionally append an `IdentityFile` entry to `~/.ssh/config`

**Environment file:**
1. Prompt: `Bitwarden item name: _`
2. Pull the item's notes field (expects key=value lines)
3. Prompt: `Save to path (e.g. ~/.env): _`
4. Write to specified path, `chmod 600`

#### 4. Cleanup

Unset `BW_SESSION` from the environment and run `bw lock` before the script exits.

### Security properties

- Session token held in a shell variable only — not in any file, not in shell history
- Script uses `read -rs` for passwords (no echo)
- `bw lock` + unset called in a `trap EXIT` to ensure cleanup even on error/interrupt

---

## Shared Conventions

Both modules:
- Source `lib/common.sh` for `log_*`, `confirm`, `install_pkg`
- Are standalone runnable: `bash modules/<name>/setup.sh`
- Keep `module.sh` thin (metadata + `module_run()` only)
- Pacman/AUR installs go through `install_pkg` — no direct `pacman` calls

---

## What Is Not In Scope

- Persistent Bitwarden unlock daemon or agent
- Automatic secret re-sync / scheduled pulls
- YubiKey PIV (smart card) setup
- Multi-user support for Bitwarden
