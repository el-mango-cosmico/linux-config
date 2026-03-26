#!/bin/bash
# Restores KDE Plasma config from the repo into ~/.config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source "$SCRIPT_DIR/../../lib/common.sh"

log_section "Restoring KDE configuration"

if [[ ! -d "$CONFIG_DIR" || -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
    log_error "No KDE config found in $CONFIG_DIR"
    log_info "Run the backup option first from a working machine."
    exit 1
fi

for f in "$CONFIG_DIR"/*; do
    dest="$HOME/.config/$(basename "$f")"
    if [[ -f "$dest" ]]; then
        local backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$dest" "$backup"
        log_info "Backed up: $(basename "$dest") → $backup"
    fi
    cp "$f" "$dest"
    log_success "Restored: $(basename "$f")"
done

log_section "Done"
log_warn "KDE config restored. You may need to log out and back in for changes to take effect."
