#!/usr/bin/env bash
# =============================================================================
# scripts/age-keygen.sh
# One-time setup: generate your age keypair and configure the environment.
# Run this ONCE per operator machine. Keep keys.txt secret.
# =============================================================================
set -euo pipefail

KEY_DIR="${SOPS_AGE_KEY_DIR:-$HOME/.config/sops/age}"
KEY_FILE="$KEY_DIR/keys.txt"

echo "[age-keygen] Creating key directory: $KEY_DIR"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

if [[ -f "$KEY_FILE" ]]; then
  echo "[age-keygen] Key file already exists at $KEY_FILE"
  echo "[age-keygen] Public key:"
  grep "^# public key:" "$KEY_FILE" | awk '{print $NF}'
  exit 0
fi

echo "[age-keygen] Generating new age keypair..."
age-keygen -o "$KEY_FILE"
chmod 600 "$KEY_FILE"

PUBLIC_KEY=$(grep "^# public key:" "$KEY_FILE" | awk '{print $NF}')
echo ""
echo "============================================================"
echo " Age keypair generated successfully."
echo " Private key: $KEY_FILE  (KEEP THIS SECRET - never share)"
echo " Public key:  $PUBLIC_KEY"
echo "============================================================"
echo ""
echo "NEXT STEPS:"
echo "  1. Add the public key above to .sops.yaml under 'recipients'"
echo "  2. Add this to your shell profile:"
echo "       export SOPS_AGE_KEY_FILE=$KEY_FILE"
echo "  3. Re-encrypt all secrets: sops updatekeys <file>"
