#!/bin/bash

# Define Starship configuration file source location
STARSHIP_CONFIG_SOURCE="$PWD/starship.toml"
STARSHIP_CONFIG_DEST="$HOME/.config/starship.toml"
ZSHRC_SOURCE="$PWD/zshrc_starter"
ZSHRC_DEST="$HOME/.zshrc"

# List of applications to check and install
declare -a installs=("zsh" "nvim" "starship")

# Checks if Fira Code and Hack Nerd Fonts are installed, installs them if not.
check_and_install_fonts() {
    # Check if Fira Code is installed
    if fc-list | grep -qi "FiraCode"; then
        echo "Fira Code fonts are already installed."
    else
        echo "Fira Code fonts not found. Installing..."
        sudo apt install -y fonts-firacode
        echo "Fira Code fonts installed."
    fi

    # Check if a specific Hack Nerd Font file is installed
    if [ -f ~/.local/share/fonts/Hack\ Regular\ Nerd\ Font\ Complete.ttf ]; then
        echo "Nerd Fonts (Hack) are already installed."
    else
        echo "Nerd Fonts not found. Installing Hack Nerd Font..."
        mkdir -p ~/.local/share/fonts
        curl -fLo ~/.local/share/fonts/HackNerdFont.zip https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Hack.zip
        
        if [ $? -eq 0 ]; then
            unzip ~/.local/share/fonts/HackNerdFont.zip -d ~/.local/share/fonts
            rm ~/.local/share/fonts/HackNerdFont.zip
            fc-cache -fv
            echo "Nerd Fonts (Hack) installed."
        else
            echo "Error: Failed to download Hack Nerd Font."
        fi
    fi
}

# Function to check if an application is installed, and install it if not
check_and_install() {
    local app_name=$1
    
    if ! command -v "$app_name" &> /dev/null; then
        echo "$app_name is not installed. Installing..."
        
        case "$app_name" in
            "zsh")
                sudo apt install zsh -y
                echo "Zsh installed."
                ;;
            "nvim")
                sudo apt install neovim -y
                echo "Neovim installed."
                ;;
            "starship")
                # Ensure fonts are installed before Starship
                check_and_install_fonts
                curl -fsSL https://starship.rs/install.sh | sh
                mkdir -p ~/.config
                cp "$STARSHIP_CONFIG_SOURCE" "$STARSHIP_CONFIG_DEST"
                echo "Starship installed and configuration copied to $STARSHIP_CONFIG_DEST."
                ;;
        esac
    else
        echo "$app_name is already installed."
        
        if [ "$app_name" == "starship" ]; then
            # Copy starship config if Starship is installed
            cp "$STARSHIP_CONFIG_SOURCE" "$STARSHIP_CONFIG_DEST"
            echo "Starship configuration copied to $STARSHIP_CONFIG_DEST."
        fi
    fi
}

# Preload the Zsh config file
if [ ! -f "$ZSHRC_DEST" ]; then
    echo "Copying starter .zshrc configuration..."
    cp "$ZSHRC_SOURCE" "$ZSHRC_DEST"
    echo "Starter .zshrc configuration copied to $ZSHRC_DEST."
else
    echo ".zshrc already exists, skipping copy."
fi

# Add Starship initialization to the .zshrc if not present
if ! grep -q "eval \"\$(starship init zsh)\"" "$ZSHRC_DEST"; then
    echo 'Adding Starship initialization to .zshrc...'
    echo 'eval "$(starship init zsh)"' >> "$ZSHRC_DEST"
else
    echo "Starship initialization already present in .zshrc."
fi

# Ensure fonts are installed before proceeding with the rest of the script
check_and_install_fonts

# Iterate through the list of installations and check each one
for app in "${installs[@]}"; do
    check_and_install "$app"
done

# Reload Zsh if it's the current shell
if [ "$SHELL" = "/bin/zsh" ] || [ "$SHELL" = "/usr/bin/zsh" ]; then
    echo "Reloading Zsh to apply Starship..."
    exec zsh
else
    echo "Starship configuration applied, but current shell is not Zsh."
fi

echo "Setup complete!"

