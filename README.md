# Mango Linux Configuration

Arch Linux setup and configuration automation — dotfiles, modules, and utility scripts.

## Quick Start

```bash
git clone <repo-url> ~/Repos/linux-config
cd ~/Repos/linux-config
./install.sh
```

`install.sh` presents a menu. Select any module or utility to run it.

## Modules

Modules live in `modules/` and are auto-discovered by `install.sh`.

| Module | What it does | Run standalone |
|--------|-------------|----------------|
| `dotfiles` | Symlinks shell, git, and prompt config | `bash modules/dotfiles/deploy.sh` |
| `nvim` | Installs Neovim with LazyVim, LSPs, and AI plugins | `bash modules/nvim/setup.sh` |
| `kde` | Backs up / restores KDE Plasma settings | `bash modules/kde/backup.sh` or `restore.sh` |
| `yubikey` | PAM U2F auth, SSH FIDO2 key, GPG / git signing | `bash modules/yubikey/setup.sh` |
| `bitwarden` | Install bw CLI, unlock with YubiKey OTP, pull SSH keys + env files | `bash modules/bitwarden/setup.sh` |

## YubiKey Setup

The `yubikey` module covers three independent flows — run any or all:

**PAM U2F** — touch your YubiKey instead of typing a password for `sudo` and login:
```bash
bash modules/yubikey/setup.sh
# Choose: 1) PAM U2F → 1) Register a YubiKey
# Then:   1) PAM U2F → 4) Configure PAM  (run with sudo)
```

**SSH FIDO2** — your YubiKey becomes your SSH key (private key never leaves the hardware):
```bash
bash modules/yubikey/setup.sh
# Choose: 2) SSH FIDO2
# Generates ~/.ssh/id_ed25519_sk — add the .pub to GitHub / authorized_keys
# On a new machine: ssh-keygen -K  to load the resident key from the YubiKey
```

**GPG / Git signing** — sign git commits so they show "Verified" on GitHub:
```bash
bash modules/yubikey/setup.sh
# Choose: 3) GPG
# Configures git to sign all commits with your YubiKey's OpenPGP key
```

## Bitwarden CLI Setup

The `bitwarden` module installs the `bw` CLI, unlocks your vault (optionally using YubiKey OTP as 2FA), and pulls secrets to their correct locations on disk.

```bash
bash modules/bitwarden/setup.sh
```

What it can pull:
- **SSH private key** — saves to `~/.ssh/<name>`, sets `chmod 600`, optionally adds to `~/.ssh/config`
- **Environment file** — saves a secure note's contents to a path you specify (e.g. `~/.env`)

Prerequisites:
- A Bitwarden account with your secrets stored as secure notes or SSH key items
- (Optional) YubiKey OTP configured as a 2FA method in your Bitwarden account settings

## Utility Scripts

| Script | What it does |
|--------|-------------|
| `scripts/bootable-usb/arch-usb-creator.sh` | Create a bootable Arch Linux USB |
| `scripts/determine-arch-ver/linux-os-discovery-updated.sh` | Detect hardware and recommend Arch version |
| `scripts/install/arch-install-script.sh` | Full Arch Linux install (run from live env) |
| `scripts/disk-encryption/encrypt-disk.sh` | Disk encryption setup |
| `scripts/import-root-ca/import-root-ca.sh` | Import a root CA certificate |
| `scripts/setup-wireguard.sh` | WireGuard VPN setup |

## Adding a New Module

See [MODULES.md](MODULES.md) for the module template and conventions.
