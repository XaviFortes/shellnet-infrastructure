#!/usr/bin/env bash
# =============================================================================
# scripts/sops-encrypt.sh
# Encrypts a plaintext secret file using SOPS + Age.
# Usage: ./scripts/sops-encrypt.sh <plaintext-file>
#
# The plaintext file MUST follow the naming convention that .sops.yaml matches:
#   - secrets.json          → encrypts to secrets.sops.json
#   - vault.yml             → encrypts to vault.sops.yml
#
# The plaintext file is deleted after encryption to avoid accidental commits.
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

# Derive output filename by injecting .sops before the extension
BASENAME=$(basename "$INPUT_FILE")
DIRNAME=$(dirname "$INPUT_FILE")
EXTENSION="${BASENAME##*.}"
STEM="${BASENAME%.*}"
OUTPUT_FILE="$DIRNAME/${STEM}.sops.${EXTENSION}"

echo "[sops-encrypt] Encrypting $INPUT_FILE → $OUTPUT_FILE"
sops --encrypt "$INPUT_FILE" > "$OUTPUT_FILE"

echo "[sops-encrypt] Removing plaintext file: $INPUT_FILE"
rm -f "$INPUT_FILE"

echo "[sops-encrypt] Done. Commit $OUTPUT_FILE safely."
