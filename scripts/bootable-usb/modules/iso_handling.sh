#!/bin/bash
# Module: iso_handling.sh
# Handles ISO download and cleanup

# Function to download Arch Linux ISO
download_iso() {
    local iso_filename="$1"
    local iso_url="$2"

    # Check if ISO already exists
    if [ -f "${iso_filename}" ]; then
        echo -e "${YELLOW}ISO file ${iso_filename} already exists.${NC}"
        read -p "Use existing file? (yes/no): " use_existing
        if [[ "$use_existing" == "yes" ]]; then
            echo -e "${GREEN}Using existing ISO file.${NC}"
            return 0
        fi
    fi

    echo -e "${GREEN}Downloading Arch Linux ISO from MIT mirror...${NC}"
    echo -e "${YELLOW}URL: ${iso_url}${NC}"
    
    # Download with wget, showing progress
    wget --progress=bar:force -O "${iso_filename}" "${iso_url}"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Download complete: ${iso_filename}${NC}"
        
        # Verify download by checking file size
        local file_size=$(stat -c %s "${iso_filename}")
        if [ "$file_size" -lt 700000000 ]; then  # ISO should be at least ~700MB
            echo -e "${RED}Warning: Downloaded file seems too small (${file_size} bytes).${NC}"
            echo -e "${YELLOW}The download might be incomplete or corrupted.${NC}"
            read -p "Do you want to continue anyway? (yes/no): " continue_anyway
            if [[ "$continue_anyway" != "yes" ]]; then
                echo -e "${RED}Operation cancelled.${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${RED}Download failed. Please check your internet connection.${NC}"
        exit 1
    fi
}

# Function to clean up downloaded ISO file
cleanup_iso() {
    local iso_file="$1"
    
    echo -e "${YELLOW}Cleaning up...${NC}"
    
    # Ask user if they want to remove the ISO file
    read -p "Do you want to remove the downloaded ISO file? (yes/no): " remove_iso
    
    if [[ "$remove_iso" == "yes" ]]; then
        if [ -f "$iso_file" ]; then
            rm -f "$iso_file"
            echo -e "${GREEN}ISO file removed successfully.${NC}"
        else
            echo -e "${RED}ISO file not found.${NC}"
        fi
    else
        echo -e "${YELLOW}ISO file kept at: $(pwd)/${iso_file}${NC}"
    fi
}
