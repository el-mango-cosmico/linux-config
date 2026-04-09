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
    ["ssh_config"]="$HOME/.ssh/config"
)

for src_rel in "${!FILES[@]}"; do
    deploy_file "$CONFIG_DIR/$src_rel" "${FILES[$src_rel]}"
done

# Prompt for git identity if .gitconfig was linked and email is still a placeholder
if grep -q "YOUR_EMAIL_HERE" "$HOME/.gitconfig" 2>/dev/null; then
    log_section "Git identity"
    log_warn ".gitconfig has a placeholder email — let's fill it in now."
    read -rp "$(echo -e "${YELLOW}Git email: ${NC}")" git_email
    read -rp "$(echo -e "${YELLOW}Git name [mango]: ${NC}")" git_name
    git_name="${git_name:-mango}"
    git config --global user.email "$git_email"
    git config --global user.name "$git_name"
    log_success "Git identity set: $git_name <$git_email>"
fi

log_section "Done"
echo -e "${GREEN}Dotfiles deployed. Reload your shell with: source ~/.zshrc${NC}"
