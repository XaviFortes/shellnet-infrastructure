#!/usr/bin/env bash
# =============================================================================
# scripts/sops-encrypt.sh
# Encrypts a plaintext secret file using SOPS + Age.
# Usage: ./scripts/sops-encrypt.sh <plaintext-file>
#
# Naming convention:
#   secrets.json      → encrypts to secrets.sops.json
#   vault.yml         → encrypts to vault.sops.yml
#
# The plaintext file is deleted after successful encryption.
# =============================================================================
set -euo pipefail

INPUT_FILE="${1:-}"

if [[ -z "$INPUT_FILE" ]]; then
  echo "Usage: $0 <plaintext-file>"
  exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: file not found: $INPUT_FILE"
  exit 1
fi

if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
  # Try the default location before failing
  DEFAULT_KEY="$HOME/.config/sops/age/keys.txt"
  if [[ -f "$DEFAULT_KEY" ]]; then
    export SOPS_AGE_KEY_FILE="$DEFAULT_KEY"
    echo "[sops-encrypt] Using age key at $DEFAULT_KEY"
    echo "[sops-encrypt] Tip: add 'export SOPS_AGE_KEY_FILE=$DEFAULT_KEY' to your ~/.zshrc"
  else
    echo "Error: SOPS_AGE_KEY_FILE is not set and no key found at $DEFAULT_KEY"
    echo "Run: ./scripts/age-keygen.sh"
    exit 1
  fi
fi

# Derive output filename by injecting .sops before the extension
BASENAME=$(basename "$INPUT_FILE")
DIRNAME=$(dirname "$INPUT_FILE")
EXTENSION="${BASENAME##*.}"
STEM="${BASENAME%.*}"
OUTPUT_FILE="$DIRNAME/${STEM}.sops.${EXTENSION}"

echo "[sops-encrypt] Encrypting $INPUT_FILE → $OUTPUT_FILE"

# Pass --output so SOPS uses the OUTPUT path to match .sops.yaml creation rules,
# not the input path. This is what caused the "no matching creation rules" error.
sops --encrypt --output "$OUTPUT_FILE" "$INPUT_FILE"

echo "[sops-encrypt] Removing plaintext file: $INPUT_FILE"
rm -f "$INPUT_FILE"

echo "[sops-encrypt] Done. Commit $OUTPUT_FILE safely."
