export PATH="$HOME/.local/bin:$PATH"

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source $ZSH/oh-my-zsh.sh

# Editor
export EDITOR='nvim'
export VISUAL='nvim'

# GPG / SSH agent
export GPG_TTY=$(tty)
if command -v gpgconf &>/dev/null; then
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    gpgconf --launch gpg-agent
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Rust / cargo env (if installed)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Kiro shell integration (if installed)
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# Aliases
[ -f ~/.zsh_aliases ] && source ~/.zsh_aliases

# Starship prompt (must be last)
eval "$(starship init zsh)"
