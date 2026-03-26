#!/bin/bash
# Dotfiles deployment — symlinks dotfiles from the repo into $HOME
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source "$SCRIPT_DIR/../../lib/common.sh"

log_section "Deploying dotfiles"

# Map: source (relative to CONFIG_DIR) → destination (absolute)
declare -A FILES=(
    [".zshrc"]="$HOME/.zshrc"
    [".zsh_aliases"]="$HOME/.zsh_aliases"
    [".gitconfig"]="$HOME/.gitconfig"
    ["starship.toml"]="$HOME/.config/starship.toml"
)

for src_rel in "${!FILES[@]}"; do
    deploy_file "$CONFIG_DIR/$src_rel" "${FILES[$src_rel]}"
done

log_section "Done"
echo -e "${GREEN}Dotfiles deployed. Reload your shell with: source ~/.zshrc${NC}"
