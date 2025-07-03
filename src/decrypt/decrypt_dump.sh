#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <input_bak_tar_file> <rsa_private_key>"
  echo "Example: $0 backup.bak.tar private.pem"
  exit 1
fi

INPUT_BAK_TAR="$1"
PRIVATE_KEY="$2"

# Extract basename prefix (strip .bak.tar)
BASENAME="${INPUT_BAK_TAR%.bak.tar}"

echo "[*] Extracting '$INPUT_BAK_TAR'..."
tar -xf "$INPUT_BAK_TAR"

# Find the encrypted tar file (*.tar.enc) extracted from tarball
ENC_FILE=$(ls "data/tmp/${BASENAME}.tar.enc" 2>/dev/null || true)
if [[ -z "$ENC_FILE" ]]; then
  echo "[!] Error: Could not find encrypted tar file '${BASENAME}.tar.enc' after extraction."
  exit 1
fi

# Find the encrypted key file (*.tar.key.*.enc), pattern with variable user part
KEY_FILE=$(ls "data/tmp/${BASENAME}.tar.key."*.enc 2>/dev/null | head -n 1 || true)
if [[ -z "$KEY_FILE" ]]; then
  echo "[!] Error: Could not find encrypted key file matching pattern '${BASENAME}.tar.key.*.enc' after extraction."
  exit 1
fi

echo "[*] Found encrypted tar file: $ENC_FILE"
echo "[*] Found encrypted key file: $KEY_FILE"

DECRYPTED_AES_KEY="${KEY_FILE}.dec"
DECRYPTED_TAR="${BASENAME}.tar"

echo "[*] Decrypting AES key file '$KEY_FILE'..."
openssl pkeyutl -decrypt -inkey "$PRIVATE_KEY" -in "$KEY_FILE" -out "$DECRYPTED_AES_KEY"

echo "[*] Decrypting encrypted tar file '$ENC_FILE'..."
openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$ENC_FILE" -out "$DECRYPTED_TAR" -pass file:"$DECRYPTED_AES_KEY"

echo "[*] Cleaning up decrypted AES key file..."
rm -f "$DECRYPTED_AES_KEY"

echo "[✓] Decryption complete: '$DECRYPTED_TAR' ready."
