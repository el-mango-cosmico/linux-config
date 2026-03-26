# Adding a New Module

Modules live in `modules/<name>/`. Each module is self-contained and auto-discovered by `install.sh`.

## Minimal module structure

```
modules/my-module/
├── module.sh        # Required: metadata + entry point
└── setup.sh         # Your actual logic (can be named anything)
```

## module.sh template

```bash
#!/bin/bash
# Copy this file to modules/<your-module>/module.sh

MODULE_NAME="my-module"             # Short identifier (no spaces)
MODULE_DESC="What this module does" # Shown in the install.sh menu

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
}
```

That's it. `install.sh` will find it automatically on next run.

---

## Common patterns

### Installing packages

```bash
source "$(dirname "$0")/../../lib/common.sh"

install_pkg neovim           # from pacman
install_pkg some-aur-pkg aur # from AUR via yay
```

### Deploying config files as symlinks

```bash
source "$(dirname "$0")/../../lib/common.sh"

# deploy_file <source> <destination>
# Prompts user if destination already exists (backup / overwrite / skip)
deploy_file "$SCRIPT_DIR/config/myfile.conf" "$HOME/.config/myfile.conf"
```

### Prompting the user

```bash
source "$(dirname "$0")/../../lib/common.sh"

if confirm "Do you want to install extra tools?"; then
    install_pkg htop
fi
```

### Logging

```bash
log_info    "Neutral info"
log_success "Something worked"
log_warn    "Non-fatal warning"
log_error   "Something failed"
log_section "Section header"
```

---

## Tips

- Put config files in `modules/<name>/config/` and symlink them via `deploy.sh`
- Use `install_pkg` instead of calling pacman directly — it checks first and handles AUR
- Keep `module.sh` thin; put real logic in a separate `setup.sh` / `deploy.sh`
- Test your module standalone: `bash modules/my-module/setup.sh`

## Existing modules

| Module | Description |
|--------|-------------|
| `dotfiles` | Shell, git, and prompt config |
| `nvim` | Neovim with LazyVim, LSPs, and AI |
| `kde` | KDE Plasma backup and restore |
