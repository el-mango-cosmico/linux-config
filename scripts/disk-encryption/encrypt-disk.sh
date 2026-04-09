#!/bin/bash

# LUKS In-Place Disk Encryption Setup
# Designed for the Razer laptop (nvme1n1) running Arch Linux.
#
# Run this from an Arch Linux live USB:
#
#   Phase 1 — encrypt root partition and configure bootloader:
#     ./encrypt-disk.sh phase1
#
#   Phase 2 — enroll TPM2 for passwordless unlock (run after successful phase1 boot):
#     ./encrypt-disk.sh phase2
#
# What this does:
#   Phase 1: encrypts /dev/nvme1n1p3 in-place, updates initramfs/bootloader
#   Phase 2: seals LUKS key to TPM2 so boot auto-unlocks (like BitLocker)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Partition layout (Razer / nvme1n1) ───────────────────────────────────────
ROOT_PART="/dev/nvme1n1p3"
EFI_PART="/dev/nvme1n1p1"
SWAP_PART="/dev/nvme1n1p2"
MAPPER_NAME="root"
MOUNT_POINT="/mnt"

# ── Helpers ───────────────────────────────────────────────────────────────────

die() { echo -e "${RED}ERROR: $*${NC}" >&2; exit 1; }
info() { echo -e "${BLUE}==> $*${NC}"; }
warn() { echo -e "${YELLOW}WARN: $*${NC}"; }
ok() { echo -e "${GREEN}OK: $*${NC}"; }

confirm() {
    local msg="$1"
    read -rp "$(echo -e "${YELLOW}${msg} (yes/no): ${NC}")" ans
    [[ "$ans" == "yes" ]] || { echo "Aborted."; exit 0; }
}

require_live_usb() {
    if findmnt / | grep -q "nvme1n1p3"; then
        die "Root partition is currently mounted as /. Boot from a live USB first."
    fi
}

require_root() {
    [[ "$(id -u)" -eq 0 ]] || die "Run as root (sudo)."
}

# ── Phase 1: Encrypt in-place ─────────────────────────────────────────────────

phase1() {
    require_root
    require_live_usb

    echo -e "\n${BLUE}=== Phase 1: LUKS In-Place Encryption ===${NC}"
    echo -e "Target      : ${CYAN}${ROOT_PART}${NC} (root partition)"
    echo -e "EFI         : ${CYAN}${EFI_PART}${NC}"
    echo -e "Mapper name : ${CYAN}/dev/mapper/${MAPPER_NAME}${NC}"
    echo -e "\n${YELLOW}This will encrypt your root partition. The process is:"
    echo -e "  1. Check + shrink filesystem (make room for LUKS header)"
    echo -e "  2. Encrypt partition in-place with cryptsetup (this takes a while)"
    echo -e "  3. Mount and chroot to update initramfs + bootloader"
    echo -e "  4. Reboot into your encrypted system${NC}"
    echo -e "\n${RED}HAVE A BACKUP BEFORE CONTINUING.${NC}"
    confirm "Are you ready to encrypt ${ROOT_PART}?"

    # ── Step 1: filesystem check and shrink ────────────────────────────────

    info "Checking filesystem integrity..."
    e2fsck -f "$ROOT_PART" || die "Filesystem check failed. Fix errors before continuing."

    info "Shrinking filesystem by 64M to make room for LUKS2 header..."
    local current_size_mb
    current_size_mb=$(( $(blockdev --getsize64 "$ROOT_PART") / 1024 / 1024 ))
    local target_size_mb=$(( current_size_mb - 64 ))
    resize2fs "$ROOT_PART" "${target_size_mb}M"
    ok "Filesystem shrunk to ${target_size_mb}M"

    # ── Step 2: encrypt in-place ───────────────────────────────────────────

    info "Starting in-place encryption of ${ROOT_PART}..."
    echo -e "${YELLOW}You will be prompted to set a LUKS passphrase. Choose a strong one —"
    echo -e "it's your fallback if TPM2 fails.${NC}\n"
    cryptsetup reencrypt --encrypt --reduce-device-size 32M "$ROOT_PART"
    ok "Encryption complete."

    local luks_uuid
    luks_uuid=$(cryptsetup luksUUID "$ROOT_PART")
    ok "LUKS UUID: ${luks_uuid}"

    # ── Step 3: mount and chroot ───────────────────────────────────────────

    info "Opening encrypted partition..."
    cryptsetup open "$ROOT_PART" "$MAPPER_NAME"

    info "Mounting filesystems..."
    mount "/dev/mapper/${MAPPER_NAME}" "$MOUNT_POINT"
    mount "$EFI_PART" "${MOUNT_POINT}/boot/efi"
    mount --bind /proc "${MOUNT_POINT}/proc"
    mount --bind /sys "${MOUNT_POINT}/sys"
    mount --bind /dev "${MOUNT_POINT}/dev"
    mount --bind /run "${MOUNT_POINT}/run"

    # Mount efivarfs so bootctl can write EFI entries
    mount -t efivarfs efivarfs "${MOUNT_POINT}/sys/firmware/efi/efivars" 2>/dev/null || true

    info "Writing crypttab..."
    echo "${MAPPER_NAME}  UUID=${luks_uuid}  none  luks" > "${MOUNT_POINT}/etc/crypttab"
    cat "${MOUNT_POINT}/etc/crypttab"

    info "Updating mkinitcpio.conf (adding encrypt hook)..."
    # Insert 'encrypt' before 'filesystems' in the HOOKS line
    sed -i 's/\(HOOKS=.*\)\(filesystems\)/\1encrypt \2/' "${MOUNT_POINT}/etc/mkinitcpio.conf"
    grep 'HOOKS=' "${MOUNT_POINT}/etc/mkinitcpio.conf"

    info "Choosing bootloader..."
    echo -e "\n  1) Install systemd-boot ${CYAN}(recommended — better TPM2 support)${NC}"
    echo -e "  2) Keep GRUB ${YELLOW}(TPM2 enrollment still works but less seamless)${NC}"
    read -rp "Bootloader choice [1/2]: " boot_choice

    arch-chroot "$MOUNT_POINT" /bin/bash -s "$luks_uuid" "$boot_choice" "$MAPPER_NAME" << 'CHROOT'
        LUKS_UUID="$1"
        BOOT_CHOICE="$2"
        MAPPER="$3"

        echo "==> Regenerating initramfs..."
        mkinitcpio -P

        if [[ "$BOOT_CHOICE" == "1" ]]; then
            echo "==> Installing systemd-boot..."
            bootctl --path=/boot/efi install

            # Create boot entry
            local_uuid=$(cryptsetup luksUUID /dev/nvme1n1p3 2>/dev/null || echo "$LUKS_UUID")
            fs_uuid=$(findmnt -no UUID /dev/mapper/${MAPPER} 2>/dev/null || blkid -s UUID -o value /dev/mapper/${MAPPER})
            kernel_ver=$(ls /usr/lib/modules/ | sort -V | tail -1)

            mkdir -p /boot/efi/loader/entries
            cat > /boot/efi/loader/loader.conf << EOF
default arch.conf
timeout 3
console-mode max
editor no
EOF
            cat > /boot/efi/loader/entries/arch.conf << EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=UUID=${LUKS_UUID}:${MAPPER} root=/dev/mapper/${MAPPER} rw quiet
EOF
            cat > /boot/efi/loader/entries/arch-fallback.conf << EOF
title   Arch Linux (fallback)
linux   /vmlinuz-linux
initrd  /initramfs-linux-fallback.img
options cryptdevice=UUID=${LUKS_UUID}:${MAPPER} root=/dev/mapper/${MAPPER} rw
EOF
            # Copy kernel and initramfs to EFI partition
            cp /boot/vmlinuz-linux /boot/efi/
            cp /boot/initramfs-linux.img /boot/efi/
            cp /boot/initramfs-linux-fallback.img /boot/efi/

            echo "==> systemd-boot installed."
        else
            echo "==> Updating GRUB for encrypted root..."
            sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LUKS_UUID}:${MAPPER} root=/dev/mapper/${MAPPER}\"|" /etc/default/grub
            grub-mkconfig -o /boot/grub/grub.cfg
            echo "==> GRUB updated."
        fi

        echo "==> Done inside chroot."
CHROOT

    info "Unmounting..."
    umount -R "$MOUNT_POINT" 2>/dev/null || true
    cryptsetup close "$MAPPER_NAME" 2>/dev/null || true

    echo -e "\n${GREEN}=== Phase 1 Complete ===${NC}"
    echo -e "Your root partition is now encrypted."
    echo -e "\n${YELLOW}Next steps:"
    echo -e "  1. Reboot: ${CYAN}reboot${NC}"
    echo -e "  2. At boot you will be prompted for your LUKS passphrase"
    echo -e "  3. After logging in, run phase 2 to enroll TPM2 (no more passphrase at boot):"
    echo -e "     ${CYAN}sudo ./encrypt-disk.sh phase2${NC}${NC}"
}

# ── Phase 2: Enroll TPM2 ──────────────────────────────────────────────────────

phase2() {
    require_root

    echo -e "\n${BLUE}=== Phase 2: TPM2 Enrollment ===${NC}"
    echo -e "This seals the LUKS key to your TPM2 chip so the drive auto-unlocks"
    echo -e "on boot — no passphrase needed (like BitLocker).\n"

    # Verify we're running on an encrypted root
    if ! cryptsetup status "$MAPPER_NAME" &>/dev/null; then
        # Try to find the encrypted root device
        local root_dev
        root_dev=$(findmnt -no SOURCE / 2>/dev/null)
        if ! cryptsetup isLuks "$ROOT_PART" &>/dev/null; then
            die "Root partition doesn't appear to be LUKS encrypted. Run phase1 first."
        fi
    fi

    # Check TPM2 is available
    if [[ ! -e /dev/tpmrm0 ]]; then
        die "TPM2 device not found at /dev/tpmrm0."
    fi
    ok "TPM2 device found."

    local luks_uuid
    luks_uuid=$(cryptsetup luksUUID "$ROOT_PART")
    info "LUKS UUID: ${luks_uuid}"

    echo -e "\n${YELLOW}TPM2 PCR policy:${NC}"
    echo -e "  PCR 0  — firmware/BIOS integrity"
    echo -e "  PCR 7  — Secure Boot state"
    echo -e "  Using PCRs 0+7 (same as BitLocker default)\n"
    echo -e "${YELLOW}Note: Re-enrollment required if you update firmware or toggle Secure Boot.${NC}\n"

    confirm "Enroll TPM2 for ${ROOT_PART}?"

    info "Enrolling TPM2 (you will be prompted for your LUKS passphrase once)..."
    systemd-cryptenroll \
        --tpm2-device=auto \
        --tpm2-pcrs=0+7 \
        "$ROOT_PART"

    ok "TPM2 enrolled."

    # Update crypttab to use tpm2-device
    info "Updating /etc/crypttab for TPM2 auto-unlock..."
    if grep -q "^${MAPPER_NAME}" /etc/crypttab; then
        sed -i "s|^${MAPPER_NAME}.*|${MAPPER_NAME}  UUID=${luks_uuid}  none  luks,tpm2-device=auto|" /etc/crypttab
    fi
    cat /etc/crypttab

    # Regenerate initramfs to pick up sd-encrypt hook (systemd-cryptenroll uses it)
    info "Checking initramfs hooks..."
    if grep -q 'encrypt' /etc/mkinitcpio.conf && ! grep -q 'sd-encrypt' /etc/mkinitcpio.conf; then
        warn "Switching initramfs hook from 'encrypt' to 'sd-encrypt' for TPM2 support..."
        sed -i 's/\benrypt\b/sd-encrypt/g; s/\bencrypt\b/sd-encrypt/g' /etc/mkinitcpio.conf
        mkinitcpio -P
    fi

    # Copy updated initramfs to EFI if using systemd-boot
    if bootctl is-installed &>/dev/null 2>&1; then
        info "Copying updated initramfs to EFI partition..."
        cp /boot/initramfs-linux.img /boot/efi/
        cp /boot/initramfs-linux-fallback.img /boot/efi/
    fi

    echo -e "\n${GREEN}=== Phase 2 Complete ===${NC}"
    echo -e "TPM2 enrolled. On next boot the drive will unlock automatically."
    echo -e "\n${YELLOW}Your LUKS passphrase is still enrolled as a fallback."
    echo -e "If TPM2 auto-unlock fails (e.g. after firmware update), use it to boot${NC}"
    echo -e "then re-run: ${CYAN}sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 ${ROOT_PART}${NC}"
}

# ── Entrypoint ────────────────────────────────────────────────────────────────

case "${1:-}" in
    phase1) phase1 ;;
    phase2) phase2 ;;
    *)
        echo -e "Usage: $0 [phase1|phase2]"
        echo -e ""
        echo -e "  ${CYAN}phase1${NC}  Run from Arch live USB — encrypts root partition in-place"
        echo -e "  ${CYAN}phase2${NC}  Run after first encrypted boot — enrolls TPM2 for auto-unlock"
        exit 1
        ;;
esac
