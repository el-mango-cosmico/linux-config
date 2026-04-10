#!/bin/bash
# Module metadata — sourced by install.sh for menu auto-discovery
MODULE_NAME="bitwarden"
MODULE_DESC="Bitwarden CLI setup: install, unlock, pull SSH keys + env files"

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
}
