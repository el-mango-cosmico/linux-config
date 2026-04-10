#!/bin/bash
MODULE_NAME="yubikey"
MODULE_DESC="YubiKey setup: PAM U2F, SSH FIDO2, GPG signing"

module_run() {
    bash "$(dirname "${BASH_SOURCE[0]}")/setup.sh"
}
