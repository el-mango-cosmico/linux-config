#!/bin/bash
# Module metadata — sourced by install.sh for menu auto-discovery
MODULE_NAME="nvim"
MODULE_DESC="Setup Neovim with LazyVim + LSPs + AI assistant"

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
}
