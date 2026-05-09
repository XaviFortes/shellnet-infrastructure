#!/usr/bin/env bash
# =============================================================================
# scripts/validate.sh
# Pre-commit / CI validation script.
# Checks that no unencrypted secrets are accidentally staged for commit.
# Run manually or wire into a pre-commit hook / GitHub Actions.
# =============================================================================
set -euo pipefail

ERRORS=0

echo "============================================================"
echo " Homelab IaC — Secret Leak Validation"
echo "============================================================"

# ---------------------------------------------------------------------------
# 1. Ensure no plaintext .tfvars files exist (only .tfvars.example allowed)
# ---------------------------------------------------------------------------
echo "[check] Scanning for plain .tfvars files..."
TFVARS=$(find . \
  -not -path './.git/*' \
  -not -path './.terragrunt-cache/*' \
  -name '*.tfvars' \
  -not -name '*.example' 2>/dev/null || true)

if [[ -n "$TFVARS" ]]; then
  echo "  FAIL: Plain .tfvars files found (should use SOPS-encrypted secrets):"
  echo "$TFVARS" | sed 's/^/    /'
  ERRORS=$((ERRORS + 1))
else
  echo "  OK"
fi

# ---------------------------------------------------------------------------
# 2. Ensure every *.sops.* file is actually SOPS-encrypted (has sops metadata)
# ---------------------------------------------------------------------------
echo "[check] Validating SOPS encryption on *.sops.* files..."
while IFS= read -r -d '' file; do
  if ! grep -q '"sops"' "$file" && ! grep -q 'sops:' "$file"; then
    echo "  FAIL: File appears unencrypted: $file"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find . \
  -not -path './.git/*' \
  -not -path './.terragrunt-cache/*' \
  \( -name '*.sops.json' -o -name '*.sops.yml' -o -name '*.sops.yaml' \) \
  -print0 2>/dev/null)

if [[ $ERRORS -eq 0 ]]; then
  echo "  OK"
fi

# ---------------------------------------------------------------------------
# 3. Check for common secret patterns in staged/tracked files
# ---------------------------------------------------------------------------
echo "[check] Scanning for secret patterns in tracked files..."
SECRET_PATTERNS=(
  'password\s*=\s*"[^"]+'
  'api_token\s*=\s*"[^"]+'
  'secret_key\s*=\s*"[^"]+'
  'access_key\s*=\s*"[^"]+'
  'PRIVATE KEY'
  'BEGIN RSA'
  'BEGIN OPENSSH'
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  MATCHES=$(git grep -l -i -E "$pattern" -- \
    ':!*.sops.*' ':!*.example' ':!*.gitignore' ':!scripts/validate.sh' 2>/dev/null || true)
  if [[ -n "$MATCHES" ]]; then
    echo "  FAIL: Pattern '$pattern' found in:"
    echo "$MATCHES" | sed 's/^/    /'
    ERRORS=$((ERRORS + 1))
  fi
done

if [[ $ERRORS -eq 0 ]]; then
  echo "  OK"
fi

# ---------------------------------------------------------------------------
# 4. Ensure age private key file is not tracked
# ---------------------------------------------------------------------------
echo "[check] Ensuring age private keys are not tracked..."
AGE_KEYS=$(git ls-files | grep -E '(keys\.txt|\.age$)' | grep -v '\.age\.pub' || true)
if [[ -n "$AGE_KEYS" ]]; then
  echo "  FAIL: Age private key file is tracked by git:"
  echo "$AGE_KEYS" | sed 's/^/    /'
  ERRORS=$((ERRORS + 1))
else
  echo "  OK"
fi

echo "============================================================"
if [[ $ERRORS -gt 0 ]]; then
  echo " RESULT: $ERRORS check(s) FAILED. Fix before committing."
  exit 1
else
  echo " RESULT: All checks passed."
fi
