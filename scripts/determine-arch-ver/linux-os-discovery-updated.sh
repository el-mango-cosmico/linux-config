#!/bin/bash

# Variable to store architecture
ARCH=""
# Variable to store CPU type
CPU_TYPE=""
# Variable to store if system is UEFI
IS_UEFI=false
# Variable to hold recommended Arch Linux version
ARCH_RECOMMENDATION=""
# Variable to store RAM in KB
TOTAL_MEM=0
# Variable to store GPU information
GPU_INFO=""
# Variable to check if system is virtual
IS_VIRTUAL=false

echo "Analyzing system to determine appropriate Arch Linux version..."

# Get architecture
ARCH=$(uname -m)

# Get CPU information
if [ "$(uname)" == "Darwin" ]; then
    # macOS
    CPU_INFO=$(sysctl -n machdep.cpu.brand_string)
    
    # Determine CPU type for Mac
    if echo "$CPU_INFO" | grep -q "Intel"; then
        CPU_TYPE="intel"
    elif echo "$CPU_INFO" | grep -q "Apple"; then
        CPU_TYPE="arm"
    fi
    
    # Get memory information
    TOTAL_MEM=$(( $(sysctl -n hw.memsize) / 1024 ))
else
    # Linux
    if [ -f /proc/cpuinfo ]; then
        CPU_INFO=$(grep -m 1 "model name" /proc/cpuinfo | cut -d ":" -f2 | sed 's/^[ \t]*//')
        
        # Determine CPU type
        if echo "$CPU_INFO" | grep -q "Intel"; then
            CPU_TYPE="intel"
        elif echo "$CPU_INFO" | grep -q "AMD"; then
            CPU_TYPE="amd"
        elif echo "$CPU_INFO" | grep -q "ARM"; then
            CPU_TYPE="arm"
        fi
        
        # Get memory information
        if [ -f /proc/meminfo ]; then
            TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        fi
    fi
fi

# Check for UEFI boot
if command -v efibootmgr >/dev/null 2>&1; then
    IS_UEFI=true
elif [ -d /sys/firmware/efi ]; then
    IS_UEFI=true
else
    IS_UEFI=false
fi

# Get GPU information
if [ "$(uname)" == "Darwin" ]; then
    # macOS
    GPU_INFO=$(system_profiler SPDisplaysDataType | grep -E "Chipset|Model|VRAM")
else
    # Linux
    if command -v lspci >/dev/null 2>&1; then
        GPU_INFO=$(lspci | grep -E "VGA|3D|Display")
    elif command -v glxinfo >/dev/null 2>&1; then
        GPU_INFO=$(glxinfo | grep -E "OpenGL vendor|OpenGL renderer")
    fi
fi

# Check for virtualization
if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT=$(systemd-detect-virt)
    if [ "$VIRT" != "none" ]; then
        IS_VIRTUAL=true
    fi
elif grep -q "^flags.*svm" /proc/cpuinfo || grep -q "^flags.*vmx" /proc/cpuinfo; then
    # Has virtualization capability, but may not be a VM
    if grep -q "hypervisor" /proc/cpuinfo; then
        IS_VIRTUAL=true
    fi
fi

# Convert memory to GB for display
MEM_GB=$(echo "scale=2; $TOTAL_MEM / 1024 / 1024" | bc)

# Determine recommended Arch Linux version
# Determine based on architecture
if [ "$ARCH" == "x86_64" ]; then
    if (( $(echo "$MEM_GB < 1" | bc -l) )); then
        ARCH_RECOMMENDATION="Arch Linux 32 (due to low RAM: ${MEM_GB}GB)"
    else
        ARCH_RECOMMENDATION="Arch Linux (x86_64)"
    fi
elif [ "$ARCH" == "i686" ] || [ "$ARCH" == "i386" ]; then
    ARCH_RECOMMENDATION="Arch Linux 32"
elif [ "$ARCH" == "aarch64" ] || [ "$ARCH" == "arm64" ]; then
    ARCH_RECOMMENDATION="Arch Linux ARM (AArch64)"
elif [ "$ARCH" == "armv7l" ] || [ "$ARCH" == "armv7" ]; then
    ARCH_RECOMMENDATION="Arch Linux ARM (ARMv7)"
elif [ "$ARCH" == "armv6l" ] || [ "$ARCH" == "armv6" ]; then
    ARCH_RECOMMENDATION="Arch Linux ARM (ARMv6)"
else
    ARCH_RECOMMENDATION="Unknown architecture ($ARCH), please check https://archlinux.org/download/ for compatibility"
fi

# Special cases
if [ "$IS_VIRTUAL" = true ]; then
    ARCH_RECOMMENDATION="$ARCH_RECOMMENDATION - Consider using a minimal installation profile for virtual environments"
fi

if [ "$IS_UEFI" = true ]; then
    ARCH_RECOMMENDATION="$ARCH_RECOMMENDATION - Use UEFI boot mode"
else
    ARCH_RECOMMENDATION="$ARCH_RECOMMENDATION - Use Legacy/BIOS boot mode"
fi

# Print results
echo -e "\n======================="
echo "SYSTEM ANALYSIS RESULTS"
echo "======================="
echo "Architecture: $ARCH"
echo "CPU Type: $CPU_TYPE"
echo "Memory: ${MEM_GB}GB RAM"
echo "Boot Mode: $([ "$IS_UEFI" = true ] && echo "UEFI" || echo "Legacy BIOS")"
echo "Virtual Machine: $([ "$IS_VIRTUAL" = true ] && echo "Yes" || echo "No")"
echo ""
echo "RECOMMENDED ARCH LINUX VERSION:"
echo "--> $ARCH_RECOMMENDATION"
echo ""

# Print installation notes
echo "INSTALLATION NOTES:"

if [ "$CPU_TYPE" == "intel" ]; then
    echo "- Install intel-ucode package for CPU microcode updates"
elif [ "$CPU_TYPE" == "amd" ]; then
    echo "- Install amd-ucode package for CPU microcode updates"
fi

if echo "$GPU_INFO" | grep -q -i "nvidia"; then
    echo "- Consider installing the nvidia drivers (nvidia package)"
elif echo "$GPU_INFO" | grep -q -i "amd\|radeon"; then
    echo "- AMD GPU detected, consider installing mesa and xf86-video-amdgpu packages"
elif echo "$GPU_INFO" | grep -q -i "intel"; then
    echo "- Intel GPU detected, consider installing mesa and xf86-video-intel packages"
fi

if (( $(echo "$MEM_GB < 2" | bc -l) )); then
    echo "- Low RAM detected. Consider using a lightweight desktop environment like LXDE or a window manager like i3"
    echo "- Create a larger swap partition (at least equal to RAM size)"
elif (( $(echo "$MEM_GB < 4" | bc -l) )); then
    echo "- Moderate RAM detected. Consider using XFCE or MATE desktop environments"
fi

echo ""
echo "Visit https://archlinux.org/download/ to download your Arch Linux version"
