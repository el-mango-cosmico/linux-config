#!/bin/bash
# Module metadata — sourced by install.sh for menu auto-discovery
MODULE_NAME="yubikey"
MODULE_DESC="YubiKey setup: PAM U2F, SSH FIDO2, GPG signing"

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
}
