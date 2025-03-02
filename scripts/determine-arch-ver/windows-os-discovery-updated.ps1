# Windows System Information Discovery Script
# Save this as Get-SystemInfo.ps1 and run in PowerShell

# Variables to track system specifications
$archType = ""
$isUEFI = $false
$totalMemoryGB = 0
$cpuType = ""
$gpuVendor = ""
$isVirtualized = $false

Write-Host "Analyzing system to determine appropriate Arch Linux version..."

# OS Information
$osInfo = Get-CimInstance Win32_OperatingSystem

# Determine architecture
if ($osInfo.OSArchitecture -match "64") {
    $archType = "x86_64"
} else {
    $archType = "i686"
}

# System Information
$compSystem = Get-CimInstance Win32_ComputerSystem

# Check for virtualization
if ($compSystem.Manufacturer -match "VMware|QEMU|VirtualBox|Xen|KVM|Parallels|Microsoft") {
    $isVirtualized = $true
}

# CPU Information
$processors = Get-CimInstance Win32_Processor
foreach ($cpu in $processors) {
    # Determine CPU type
    if ($cpu.Name -match "Intel") {
        $cpuType = "intel"
    } elseif ($cpu.Name -match "AMD") {
        $cpuType = "amd"
    } elseif ($cpu.Name -match "ARM") {
        $cpuType = "arm"
        $archType = "aarch64"
    }
}

# Memory Information
$totalMemoryGB = [math]::Round($compSystem.TotalPhysicalMemory / 1GB, 2)

# Graphics Information
$gpus = Get-CimInstance Win32_VideoController
foreach ($gpu in $gpus) {
    # Determine GPU vendor
    if ($gpu.Name -match "NVIDIA") {
        $gpuVendor = "nvidia"
    } elseif ($gpu.Name -match "AMD|ATI|Radeon") {
        $gpuVendor = "amd"
    } elseif ($gpu.Name -match "Intel") {
        $gpuVendor = "intel"
    }
}

# Check for UEFI
try {
    $uefiTest = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
    $isUEFI = $true
} catch {
    # If secure boot check fails, try an alternative method
    try {
        $regValue = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State" -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue
        if ($regValue -ne $null) {
            $isUEFI = $true
        } else {
            $isUEFI = $false
        }
    } catch {
        # Default to checking firmware type
        if ($compSystem.BootupState -match "UEFI") {
            $isUEFI = $true
        } else {
            $isUEFI = $false
        }
    }
}

# Determine recommended Arch Linux version
$archRecommendation = "Unknown, please check compatibility"

# Determine based on architecture
if ($archType -eq "x86_64") {
    if ($totalMemoryGB -lt 1) {
        $archRecommendation = "Arch Linux 32 (due to low RAM: ${totalMemoryGB}GB)"
    } else {
        $archRecommendation = "Arch Linux (x86_64)"
    }
} elseif ($archType -eq "i686") {
    $archRecommendation = "Arch Linux 32"
} elseif ($archType -eq "aarch64") {
    $archRecommendation = "Arch Linux ARM (AArch64)"
}

# Special cases
if ($isVirtualized) {
    $archRecommendation = "$archRecommendation - Consider using a minimal installation profile for virtual environments"
}

if ($isUEFI) {
    $archRecommendation = "$archRecommendation - Use UEFI boot mode"
} else {
    $archRecommendation = "$archRecommendation - Use Legacy/BIOS boot mode"
}

# Print results
Write-Host "`n======================="
Write-Host "SYSTEM ANALYSIS RESULTS"
Write-Host "======================="
Write-Host "Architecture: $archType"
Write-Host "CPU Type: $cpuType"
Write-Host "Memory: ${totalMemoryGB}GB RAM"
Write-Host "Boot Mode: $(if ($isUEFI) {'UEFI'} else {'Legacy BIOS'})"
Write-Host "Virtual Machine: $(if ($isVirtualized) {'Yes'} else {'No'})"
Write-Host ""
Write-Host "RECOMMENDED ARCH LINUX VERSION:"
Write-Host "--> $archRecommendation"
Write-Host ""

# Print installation notes
Write-Host "INSTALLATION NOTES:"

if ($cpuType -eq "intel") {
    Write-Host "- Install intel-ucode package for CPU microcode updates"
} elseif ($cpuType -eq "amd") {
    Write-Host "- Install amd-ucode package for CPU microcode updates"
}

if ($gpuVendor -eq "nvidia") {
    Write-Host "- Consider installing the nvidia drivers (nvidia package)"
} elseif ($gpuVendor -eq "amd") {
    Write-Host "- AMD GPU detected, consider installing mesa and xf86-video-amdgpu packages"
} elseif ($gpuVendor -eq "intel") {
    Write-Host "- Intel GPU detected, consider installing mesa and xf86-video-intel packages"
}

if ($totalMemoryGB -lt 2) {
    Write-Host "- Low RAM detected. Consider using a lightweight desktop environment like LXDE or a window manager like i3"
    Write-Host "- Create a larger swap partition (at least equal to RAM size)"
} elseif ($totalMemoryGB -lt 4) {
    Write-Host "- Moderate RAM detected. Consider using XFCE or MATE desktop environments"
}

# Windows-specific notes
Write-Host "- Consider using dual boot instead of replacing Windows completely"
Write-Host "- Make sure to disable Fast Startup and Hibernation in Windows before installing"
Write-Host "- Back up important data before installation"

if ($isUEFI) {
    Write-Host "- Disable Secure Boot in UEFI before installing Arch Linux"
    Write-Host "- Consider creating a separate EFI partition (550MB) if not already present"
}

Write-Host "`nVisit https://archlinux.org/download/ to download your Arch Linux version"
