#!/bin/bash

set -e # Exit on error

# Function to test signing and verification with retry
test_signing() {
  local sign_token="$1"
  local attempts=0
  local max_attempts=3

  echo "📄 Creating test file for signing..."
  echo "YubiKey signing test" >testfile.txt

  while [[ $attempts -lt $max_attempts ]]; do
    echo "🔏 Signing the test file (Attempt $((attempts + 1))/$max_attempts)..."

    if openssl dgst -sha256 -engine pkcs11 -keyform engine \
      -sign "pkcs11:token=${sign_token};object=PIV AUTH key" \
      -out testfile.sig testfile.txt; then
      echo "✅ File signed successfully!"
      break
    else
      echo "❌ Signing failed! Retrying..."
      attempts=$((attempts + 1))
      sleep 2
    fi
  done

  if [[ $attempts -ge $max_attempts ]]; then
    echo "❌ Signing failed after $max_attempts attempts. Exiting."
    exit 1
  fi

  echo "🔍 Verifying signature..."
  openssl x509 -in "$ROOT_CERT" -noout -subject -issuer
  openssl dgst -sha256 -engine pkcs11 -keyform engine \
    -verify "pkcs11:token=${sign_token};object=PIV AUTH pubkey" \
    -signature testfile.sig testfile.txt && echo "✅ Signature verified!" || echo "❌ Signature verification failed!"

  echo "📜 Signature Output:"
  cat testfile.sig | base64

  echo "🔎 Certificate Information:"
  openssl x509 -in "$ROOT_CERT" -text -noout | grep -E 'Issuer:|Subject:'
}

# Prompt for server name
read -p "Enter the server name (e.g., cosmic-garden.home): " SERVER_NAME

# Set file names
ROOT_KEY="root_ca_key.pem"
ROOT_CSR="root_ca.csr"
ROOT_CERT="root_ca.crt"
SERVER_KEY="${SERVER_NAME}_key.pem"
SERVER_CSR="${SERVER_NAME}.csr"
SERVER_CERT="${SERVER_NAME}.crt"

# Set the YubiKey PIV slot (9A for authentication)
SLOT="9a"

# Set PKCS11 module path
export PKCS11_MODULE="/usr/lib64/pkcs11/opensc-pkcs11.so"

# Function to ensure YubiKey is inserted
wait_for_yubikey() {
  while ! ykman piv info &>/dev/null; do
    echo -e "⏳ Waiting for YubiKey to be inserted..."
    sleep 2
  done
}

# Function to prompt user for YubiKey swap (only prompts twice)
prompt_swap() {
  if [[ "$SWAP_COUNT" -ge 1 ]]; then
    return
  fi
  SWAP_COUNT=$((SWAP_COUNT + 1))
  echo -e "\n🔄 Swap YubiKeys now and press [Enter] when ready..."
  read -r
  wait_for_yubikey
}

# Ensure required tools are installed
if ! command -v ykman &>/dev/null || ! command -v openssl &>/dev/null; then
  echo "❌ Error: 'ykman' or 'openssl' not found. Install them first."
  exit 1
fi

SWAP_COUNT=0
echo "🚀 Starting YubiKey backup process..."
wait_for_yubikey

# Generate and sign certificates
echo "🔑 Generating Root CA key and CSR..."
openssl ecparam -genkey -name prime256v1 -out "$ROOT_KEY"
openssl req -new -key "$ROOT_KEY" -out "$ROOT_CSR" -subj "/CN=$SERVER_NAME"

echo "📜 Signing Root CA certificate..."
openssl x509 -req -in "$ROOT_CSR" -signkey "$ROOT_KEY" -out "$ROOT_CERT" -days 3650 -sha256

echo "🔑 Generating Server Key and CSR..."
openssl ecparam -genkey -name prime256v1 -out "$SERVER_KEY"
openssl req -new -key "$SERVER_KEY" -out "$SERVER_CSR" -subj "/CN=$SERVER_NAME"

echo "📜 Signing Server Certificate..."
openssl x509 -req -in "$SERVER_CSR" -CA "$ROOT_CERT" -CAkey "$ROOT_KEY" -CAcreateserial -out "$SERVER_CERT" -days 730 -sha256

echo -e "\n🔐 Insert your PRIMARY YubiKey and press [Enter]..."
read -r
wait_for_yubikey

echo "⬆️ Importing Root CA private key to PRIMARY YubiKey..."
ykman piv keys import "$SLOT" "$ROOT_KEY"
ykman piv certificates import "$SLOT" "$ROOT_CERT"

test_signing "Root CA"

prompt_swap

echo "⬆️ Importing Root CA private key to BACKUP YubiKey..."
ykman piv keys import "$SLOT" "$ROOT_KEY"
ykman piv certificates import "$SLOT" "$ROOT_CERT"

test_signing "Root CA"

echo "🧹 Securely deleting local private key files..."
shred -u "$ROOT_KEY" "$SERVER_KEY"
rm -f "$ROOT_CSR" "$SERVER_CSR"

echo "🎉 All done! Both YubiKeys have been successfully backed up and validated."
