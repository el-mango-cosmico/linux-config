#!/bin/bash

# WireGuard + systemd-resolved setup with SSID auto-toggle

# For Arch Linux - Enhanced version

set -euo pipefail

# Configuration

readonly WG_INTERFACE=“wg1”
readonly WG_CONF=”/etc/wireguard/${WG_INTERFACE}.conf”
readonly DISPATCHER=”/etc/NetworkManager/dispatcher.d/90-wg-autoconnect.sh”
readonly LOG_TAG=“WireGuard-Setup”

# Color codes for output

readonly RED=’\033[0;31m’
readonly GREEN=’\033[0;32m’
readonly YELLOW=’\033[1;33m’
readonly BLUE=’\033[0;34m’
readonly NC=’\033[0m’ # No Color

# Logging functions

log_info() {
echo -e “${BLUE}[INFO]${NC} $1”
}

log_warn() {
echo -e “${YELLOW}[WARN]${NC} $1”
}

log_error() {
echo -e “${RED}[ERROR]${NC} $1”
}

log_success() {
echo -e “${GREEN}[SUCCESS]${NC} $1”
}

# Error handling

cleanup() {
local exit_code=$?
if [[ $exit_code -ne 0 ]]; then
log_error “Script failed with exit code $exit_code”
fi
exit $exit_code
}
trap cleanup EXIT

# Validation functions

validate_private_key() {
local key=”$1”
if [[ ${#key} -ne 44 ]] || [[ ! “$key” =~ ^[A-Za-z0-9+/]*=*$ ]]; then
log_error “Invalid private key format”
return 1
fi
return 0
}

validate_endpoint() {
local endpoint=”$1”
if [[ ! “$endpoint” =~ ^[^:]+:[0-9]+$ ]]; then
log_error “Invalid endpoint format. Expected format: IP:PORT”
return 1
fi
return 0
}

# Check if running as root

check_root() {
if [[ $EUID -eq 0 ]]; then
log_error “This script should not be run as root”
exit 1
fi
}

# Verify sudo access

check_sudo() {
if ! sudo -n true 2>/dev/null; then
log_info “This script requires sudo privileges”
sudo -v || exit 1
fi
}

# Check system compatibility

check_system() {
if [[ ! -f /etc/arch-release ]]; then
log_warn “This script is designed for Arch Linux”
read -rp “Continue anyway? [y/N] “ -n 1 choice
echo
[[ “$choice” =~ ^[Yy]$ ]] || exit 1
fi
}

# Check if systemd-resolved is available

check_systemd_resolved() {
if ! systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1; then
log_error “systemd-resolved is not available on this system”
exit 1
fi
}

# Backup existing configuration

backup_config() {
if [[ -f “$WG_CONF” ]]; then
local backup_file=”${WG_CONF}.backup.$(date +%Y%m%d_%H%M%S)”
log_info “Backing up existing config to $backup_file”
sudo cp “$WG_CONF” “$backup_file”
fi
}

# Install required packages

install_packages() {
log_info “Installing required packages…”

``
local packages=("wireguard-tools" "systemd-resolvconf")
local missing_packages=()

for pkg in "${packages[@]}"; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        missing_packages+=("$pkg")
    fi
done

if [[ ${#missing_packages[@]} -gt 0 ]]; then
    log_info "Installing: ${missing_packages[*]}"
    if ! sudo pacman -Sy --needed --noconfirm "${missing_packages[@]}"; then
        log_error "Failed to install packages"
        exit 1
    fi
else
    log_success "All required packages already installed"
fi
``

}

# Handle openresolv cleanup

handle_openresolv() {
if pacman -Q openresolv >/dev/null 2>&1; then
log_warn “Detected openresolv (resolvconf) which may conflict with systemd-resolved”
echo “Options:”
echo “  1) Remove openresolv and use systemd-resolved (recommended)”
echo “  2) Keep openresolv (may cause DNS issues)”
echo “  3) Abort setup”

``
    while true; do
        read -rp "Choose option [1-3]: " -n 1 choice
echo
        case $choice in
            1)
                log_info "Removing openresolv..."
                if sudo pacman -Rns --noconfirm openresolv; then
                    log_success "Removed openresolv"
                else
                    log_error "Failed to remove openresolv"
                    exit 1
                fi
                break
                ;;
            2)
                log_warn "Keeping openresolv - DNS resolution may not work properly"
                break
                ;;
            3)
                log_info "Setup aborted"
                exit 0
                ;;
            *)
                echo "Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
fi
``

}

# Setup systemd-resolved

setup_systemd_resolved() {
log_info “Configuring systemd-resolved…”

``
# Enable and start systemd-resolved
sudo systemctl enable systemd-resolved >/dev/null 2>&1
if ! sudo systemctl is-active --quiet systemd-resolved; then
    sudo systemctl start systemd-resolved
fi

# Setup resolv.conf symlink
local current_resolv=$(readlink -f /etc/resolv.conf 2>/dev/null || echo "")
local target_resolv="/run/systemd/resolve/stub-resolv.conf"

if [[ "$current_resolv" != "$target_resolv" ]]; then
    log_info "Updating /etc/resolv.conf symlink"
    sudo rm -f /etc/resolv.conf
    sudo ln -sf "$target_resolv" /etc/resolv.conf
fi

log_success "systemd-resolved configured"
``

}

# Generate WireGuard configuration

generate_wireguard_config() {
local private_key=””
local public_key=””

``
if [[ -f "$WG_CONF" ]]; then
    log_info "WireGuard configuration already exists at $WG_CONF"
    read -rp "Regenerate configuration? [y/N] " -n 1 recreate
echo
    [[ "$recreate" =~ ^[Yy]$ ]] || return 0
    backup_config
fi

echo
echo "WireGuard Key Management:"
echo "  1) Generate new key pair"
echo "  2) Use existing private key"
echo "  3) Skip configuration generation"

while true; do
    read -rp "Choose option [1-3]: " -n 1 key_choice
echo
    case $key_choice in
        1)
            log_info "Generating new key pair..."
            umask 077
            private_key=$(wg genkey)
            public_key=$(echo "$private_key" | wg pubkey)
            
echo
            log_success "Generated keys:"
            echo "  Private key: $private_key"
            echo "  Public key:  $public_key"
            echo
            log_warn "⚠️  Save the public key - you'll need to add it to your server"
            echo
            read -rp "Press Enter to continue..."
            break
            ;;
        2)
            while true; do
                echo
                read -rp "Enter your private key: " private_key
                if validate_private_key "$private_key"; then
                    public_key=$(echo "$private_key" | wg pubkey)
                    log_info "Derived public key: $public_key"
                    break
                fi
            done
            break
            ;;
        3)
            log_info "Skipping configuration generation"
            return 0
            ;;
        *)
            echo "Invalid choice. Please enter 1, 2, or 3."
            ;;
    esac
done

# Get server configuration
echo
log_info "Server Configuration:"

local server_pubkey=""
while [[ -z "$server_pubkey" ]]; do
    read -rp "Enter server public key: " server_pubkey
    if ! validate_private_key "$server_pubkey"; then
        server_pubkey=""
    fi
done

local endpoint=""
while [[ -z "$endpoint" ]]; do
    read -rp "Enter server endpoint (IP:PORT): " endpoint
    if ! validate_endpoint "$endpoint"; then
        endpoint=""
    fi
done

# Optional: Custom client IP
local client_ip="192.168.169.2/24"
read -rp "Client IP address [$client_ip]: " custom_ip
[[ -n "$custom_ip" ]] && client_ip="$custom_ip"

# Optional: Custom DNS
local dns_servers="1.1.1.1, 8.8.8.8"
read -rp "DNS servers [$dns_servers]: " custom_dns
[[ -n "$custom_dns" ]] && dns_servers="$custom_dns"

# Create configuration
log_info "Creating WireGuard configuration..."

sudo install -m 600 /dev/null "$WG_CONF"
sudo tee "$WG_CONF" >/dev/null <<EOF
```

[Interface]
Address = $client_ip
PrivateKey = $private_key
DNS = $dns_servers

[Peer]
PublicKey = $server_pubkey
Endpoint = $endpoint
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

```
log_success "WireGuard configuration created at $WG_CONF"
```

}

# Create NetworkManager dispatcher script

create_dispatcher_script() {
log_info “Creating NetworkManager dispatcher script…”

``
# Get trusted SSIDs from user
echo
echo "Configure trusted SSIDs (VPN will be disabled on these networks):"
echo "Enter SSIDs one per line. Press Enter on empty line when done."

local trusted_ssids=()
while true; do
    read -rp "SSID: " ssid
    if [[ -z "$ssid" ]]; then
        break
    fi
    trusted_ssids+=("$ssid")
echo "Added: $ssid"
done

if [[ ${#trusted_ssids[@]} -eq 0 ]]; then
    log_warn "No trusted SSIDs configured. VPN will always be active."
    trusted_ssids=("__NEVER_MATCH__")
fi

# Create the dispatcher script
sudo tee "$DISPATCHER" >/dev/null <<EOF
```
#!/bin/bash

# Auto-toggle WireGuard based on Wi-Fi SSID

# Generated by WireGuard setup script

set -euo pipefail

readonly IFACE=”$1”
readonly STATUS=”$2”
readonly WG_CONN_NAME=”$WG_INTERFACE”
readonly LOG_TAG=“WireGuard-Dispatcher”

# Trusted SSIDs (VPN disabled on these networks)

readonly TRUSTED_SSIDS=($(printf ’”%s” ’ “${trusted_ssids[@]}”))

# Only process interface up events

[[ “$STATUS” == “up” ]] || exit 0

# Skip if this is a WireGuard interface

[[ “$IFACE” != wg* ]] || exit 0

# Only process Wi-Fi interfaces

TYPE=$(/usr/bin/nmcli -t -f GENERAL.TYPE device show “$IFACE” 2>/dev/null | cut -d: -f2) || exit 0
[[ “$TYPE” == “wifi” ]] || exit 0

# Small delay to ensure Wi-Fi connection is fully established

sleep 2

# Get current SSID

SSID=$(/usr/bin/nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: ‘$1==“yes”{print $2}’) || exit 0

# Log the event

/usr/bin/logger -t “$LOG_TAG” “Processing interface=$IFACE status=$STATUS ssid=$SSID”

[[ -n “$SSID” ]] || exit 0

# Check if current SSID is trusted

is_trusted=0
for trusted_ssid in “${TRUSTED_SSIDS[@]}”; do
if [[ “$SSID” == “$trusted_ssid” ]]; then
is_trusted=1
break
fi
done

# Get current VPN status

vpn_active=0
if /usr/bin/wg show “$WG_CONN_NAME” >/dev/null 2>&1; then
vpn_active=1
fi

if [[ $is_trusted -eq 1 ]]; then
# Trusted network - disable VPN if active
if [[ $vpn_active -eq 1 ]]; then
if /usr/bin/wg-quick down “$WG_CONN_NAME” 2>/dev/null; then
/usr/bin/logger -t “$LOG_TAG” “Trusted SSID ‘$SSID’ → VPN disabled”
/usr/bin/notify-send “WireGuard” “VPN disabled on trusted network ‘$SSID’” 2>/dev/null || true
fi
fi
else
# Untrusted network - enable VPN if not active
if [[ $vpn_active -eq 0 ]]; then
if /usr/bin/wg-quick up “$WG_CONN_NAME” 2>/dev/null; then
/usr/bin/logger -t “$LOG_TAG” “Untrusted SSID ‘$SSID’ → VPN enabled”
/usr/bin/notify-send “WireGuard” “VPN enabled on untrusted network ‘$SSID’” 2>/dev/null || true
fi
fi
fi
EOF

```
sudo chmod +x "$DISPATCHER"
log_success "Dispatcher script created at $DISPATCHER"
```

}

# Test configuration
test_configuration() {
echo
read -rp “Test WireGuard configuration now? [y/N] “ -n 1 test_now
echo

``
if [[ "$test_now" =~ ^[Yy]$ ]]; then
    log_info "Testing WireGuard connection..."
    
    if sudo wg-quick up "$WG_INTERFACE"; then
        log_success "WireGuard connection established"
        
        # Test connectivity
        log_info "Testing connectivity..."
        if timeout 10 ping -c 3 1.1.1.1 >/dev/null 2>&1; then
            log_success "Internet connectivity confirmed"
        else
            log_warn "Internet connectivity test failed"
        fi
        
        # Show connection status
        echo
        echo "Connection status:"
        sudo wg show "$WG_INTERFACE"
        
        echo
        read -rp "Keep connection active? [Y/n] " -n 1 keep_active
echo
        
        if [[ ! "$keep_active" =~ ^[Nn]$ ]]; then
            log_info "Keeping WireGuard connection active"
        else
            sudo wg-quick down "$WG_INTERFACE"
            log_info "WireGuard connection closed"
        fi
    else
        log_error "Failed to establish WireGuard connection"
        log_info "Check your configuration in $WG_CONF"
    fi
fi
```

}

# Print final instructions

print_final_instructions() {
echo
echo “━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━”
log_success “Setup Complete!”
echo “━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━”
echo
echo “✔ WireGuard tools installed”
echo “✔ systemd-resolved configured”
echo “✔ Configuration file: $WG_CONF”
echo “✔ Auto-toggle script: $DISPATCHER”
echo
echo “Manual Commands:”
echo “  Start VPN:  sudo wg-quick up $WG_INTERFACE”
echo “  Stop VPN:   sudo wg-quick down $WG_INTERFACE”
echo “  Status:     sudo wg show”
echo
echo “Monitoring:”
echo “  System logs:     journalctl -fu NetworkManager -t WireGuard-Dispatcher”
echo “  Connection info: sudo wg show $WG_INTERFACE”
echo
echo “The VPN will automatically toggle based on your Wi-Fi SSID.”
echo “Reconnect to Wi-Fi to test the auto-toggle feature.”
}

# Main execution

main() {
echo “╔═══════════════════════════════════════════════════╗”
echo “║         WireGuard + systemd-resolved Setup       ║”
echo “║              Enhanced Arch Linux Script          ║”
echo “╚═══════════════════════════════════════════════════╝”
echo

```
check_root
check_sudo
check_system
check_systemd_resolved

handle_openresolv
install_packages
setup_systemd_resolved
generate_wireguard_config
create_dispatcher_script
test_configuration
print_final_instructions
```

}

# Run main function

main “$@”