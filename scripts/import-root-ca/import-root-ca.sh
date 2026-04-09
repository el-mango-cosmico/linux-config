#!/bin/bash

set -e

# Import a root CA certificate into the Arch Linux system trust store.
# Usage: sudo ./import-root-ca.sh <path-to-cert.pem>

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (sudo).${NC}"
    exit 1
fi

CERT_FILE="${1:-}"

if [[ -z "$CERT_FILE" ]]; then
    read -rp "Path to root CA cert (.pem or .crt): " CERT_FILE
fi

if [[ ! -f "$CERT_FILE" ]]; then
    echo -e "${RED}File not found: $CERT_FILE${NC}"
    exit 1
fi

# Validate it's actually a certificate
if ! openssl x509 -in "$CERT_FILE" -noout 2>/dev/null; then
    echo -e "${RED}Not a valid PEM certificate: $CERT_FILE${NC}"
    exit 1
fi

SUBJECT=$(openssl x509 -in "$CERT_FILE" -noout -subject 2>/dev/null | sed 's/subject=//')
EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | sed 's/notAfter=//')

echo -e "\n${BLUE}Certificate details:${NC}"
echo -e "  Subject : $SUBJECT"
echo -e "  Expires : $EXPIRY"

# Derive a clean filename from the cert CN or the input filename
CN=$(openssl x509 -in "$CERT_FILE" -noout -subject 2>/dev/null \
    | grep -oP '(?<=CN\s=\s)[^,]+' | head -1 \
    | tr ' ' '-' | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9._-]//g')

if [[ -z "$CN" ]]; then
    CN=$(basename "$CERT_FILE" | sed 's/\.[^.]*$//')
fi

DEST="/etc/ca-certificates/trust-source/anchors/${CN}.crt"

echo -e "\n${YELLOW}Installing to: $DEST${NC}"
read -rp "Proceed? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "${YELLOW}Aborted.${NC}"
    exit 0
fi

cp "$CERT_FILE" "$DEST"
chmod 644 "$DEST"
trust extract-compat

echo -e "\n${GREEN}Root CA imported successfully.${NC}"
echo -e "Verify with: trust list | grep -A2 '${CN}'"
