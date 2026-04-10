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

cmd_install()   { log_warn "Install: not yet implemented"; }
cmd_login()     { log_warn "Login: not yet implemented"; }
show_pull_menu(){ log_warn "Pull menu: not yet implemented"; }

cmd_install
cmd_login
show_pull_menu
