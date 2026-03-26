#!/bin/bash
# Module metadata — sourced by install.sh for menu auto-discovery
MODULE_NAME="kde"
MODULE_DESC="Backup / restore KDE Plasma configuration"

module_run() {
    local SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
    echo ""
    echo "  1) Backup current KDE config to repo"
    echo "  2) Restore KDE config from repo"
    read -rp "Choice [1/2]: " choice
    case "$choice" in
        1) bash "$SCRIPT_DIR/backup.sh" ;;
        2) bash "$SCRIPT_DIR/restore.sh" ;;
        *) echo "Invalid choice." ;;
    esac
}
