#!/bin/bash
# Module: check_dependencies.sh
# Handles checking for dependencies and sudo privileges

# Function to check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run this script with sudo or as root${NC}"
        exit 1
    fi
}

# Function to check if required tools are installed
check_dependencies() {
    local deps=("wget" "dd" "grep" "rsync")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}The following dependencies are missing:${NC}"
        printf "  %s\n" "${missing[@]}"
        echo -e "${YELLOW}Please install them using your package manager and try again.${NC}"
        exit 1
    fi
}
