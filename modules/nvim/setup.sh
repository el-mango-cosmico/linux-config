#!/bin/bash
# Neovim setup — installs neovim, a Nerd Font, and symlinks the LazyVim config
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

log_section "Setting up Neovim with LazyVim"

# 1. Install neovim
install_pkg neovim

# 2. Install a Nerd Font (ttf-jetbrains-mono-nerd covers most icons LazyVim uses)
install_pkg ttf-jetbrains-mono-nerd

# 3. Install build tools (required for avante.nvim native component)
install_pkg base-devel  # provides make, gcc, etc.

# 4. Install dependencies used by various plugins
install_pkg ripgrep     # telescope live grep
install_pkg fd          # telescope file finder
install_pkg lazygit aur # lazygit UI (LazyVim has built-in support)
install_pkg fzf         # fuzzy finder

# 4. Symlink nvim config
deploy_file "$SCRIPT_DIR/config" "$HOME/.config/nvim"

log_section "First-launch plugin install"
echo ""
log_info "Launching nvim to install plugins headlessly — this may take ~30s..."
nvim --headless "+Lazy! sync" +qa && log_success "Plugins installed" || log_warn "Plugin install returned non-zero — check output above if something looks wrong"

log_section "Done"
cat <<EOF

${GREEN}Neovim is ready!${NC}

Key things to know:
  ${CYAN}<Space>${NC}           Leader key (most shortcuts start here)
  ${CYAN}<Space><Space>${NC}    Find files
  ${CYAN}<Space>sg${NC}         Live grep (search in files)
  ${CYAN}<Space>e${NC}          File explorer
  ${CYAN}<Space>aa${NC}         Ask Avante AI (requires ANTHROPIC_API_KEY)
  ${CYAN}<C-\\>${NC}            Toggle floating terminal (run 'claude' here)
  ${CYAN}?${NC}                 Show keymaps in any which-key popup

See modules/nvim/KEYMAPS.md for a full cheatsheet.

${YELLOW}NOTE:${NC} Avante (AI assistant) needs ${CYAN}ANTHROPIC_API_KEY${NC} set in your environment.
Add it to ~/.zshrc or ~/.zsh_aliases when you have one.
EOF
