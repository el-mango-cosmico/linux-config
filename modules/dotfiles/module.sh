#!/bin/bash
# Module metadata — sourced by install.sh for menu auto-discovery
MODULE_NAME="dotfiles"
MODULE_DESC="Deploy dotfiles (zsh, aliases, git, starship)"

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/deploy.sh"
}
