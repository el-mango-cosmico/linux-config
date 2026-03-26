#!/bin/bash
# Captures current KDE Plasma config into the repo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source "$SCRIPT_DIR/../../lib/common.sh"

log_section "Backing up KDE configuration"

mkdir -p "$CONFIG_DIR"

# Files to capture — add more here as needed
KDE_FILES=(
    "$HOME/.config/kdeglobals"
    "$HOME/.config/plasmarc"
    "$HOME/.config/plasmashellrc"
    "$HOME/.config/kwinrc"
    "$HOME/.config/plasma-localerc"
    "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    "$HOME/.config/plasmanotifyrc"
)

for f in "${KDE_FILES[@]}"; do
    if [[ -f "$f" ]]; then
        cp "$f" "$CONFIG_DIR/$(basename "$f")"
        log_success "Captured: $(basename "$f")"
    else
        log_warn "Not found (skipped): $f"
    fi
done

log_section "Done"
log_info "KDE configs saved to: $CONFIG_DIR"
log_info "Commit the changes to persist them in the repo."
