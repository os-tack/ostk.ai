#!/usr/bin/env bash
# bootstrap-ceremony.sh — mint @ostk.ai and sign the genesis commit
#
# Requires:
#   OSTK_AI_GH_USER_BOOTSTRAP in haystack keychain
#   gpg installed
#   @scott key (955AF54E) on this machine
#   @haystack.prime key (99B076C9) on this machine
#
# Run: bash bootstrap-ceremony.sh

set -euo pipefail

OSTK_EMAIL="prime@ostk.ai"
OSTK_NAME="ostk.ai"
SCOTT_KEY="955AF54E"
KERNEL_KEY="99B076C9"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== ostk.ai bootstrap ceremony ==="
echo ""

# ── Step 1: Verify bootstrap token ────────────────────────────────────────────

echo "1. Verifying OSTK_AI_GH_USER_BOOTSTRAP..."
OSTK_TOKEN=$(haystack secret get OSTK_AI_GH_USER_BOOTSTRAP 2>/dev/null)
if [ -z "$OSTK_TOKEN" ] || [ ${#OSTK_TOKEN} -lt 10 ]; then
  echo "   ERROR: OSTK_AI_GH_USER_BOOTSTRAP not set or invalid"
  echo "   Run: haystack secret set OSTK_AI_GH_USER_BOOTSTRAP --value <token>"
  exit 1
fi

GH_USER=$(curl -fsSL -H "Authorization: Bearer ${OSTK_TOKEN}" \
  https://api.github.com/user | python3 -c "import json,sys; print(json.load(sys.stdin).get('login','?'))")
echo "   GitHub user: @${GH_USER}"
if [ "$GH_USER" = "?" ]; then
  echo "   ERROR: token invalid or expired"
  exit 1
fi
echo "   ✓ authenticated as @${GH_USER}"
echo ""

# ── Step 2: Generate @ostk.ai GPG key ─────────────────────────────────────────

echo "2. Checking for existing @ostk.ai key..."
if gpg --list-keys "${OSTK_EMAIL}" 2>/dev/null | grep -q "${OSTK_EMAIL}"; then
  OSTK_KEY=$(gpg --list-keys --with-colons "${OSTK_EMAIL}" | grep '^fpr' | head -1 | cut -d: -f10)
  echo "   Key already exists: ${OSTK_KEY}"
else
  echo "   Generating @ostk.ai key (ed25519)..."
  gpg --batch --gen-key <<EOF
Key-Type: eddsa
Key-Curve: Ed25519
Key-Usage: sign
Subkey-Type: ecdh
Subkey-Curve: Curve25519
Subkey-Usage: encrypt
Name-Real: ${OSTK_NAME}
Name-Comment: root key — minted v1.1, certified by @scott + @haystack.prime
Name-Email: ${OSTK_EMAIL}
Expire-Date: 2y
%no-protection
%commit
EOF
  OSTK_KEY=$(gpg --list-keys --with-colons "${OSTK_EMAIL}" | grep '^fpr' | head -1 | cut -d: -f10)
  echo "   ✓ Key generated: ${OSTK_KEY}"
fi
echo ""

# ── Step 3: Co-sign the @ostk.ai key ──────────────────────────────────────────

echo "3. Co-signing @ostk.ai key (MINT ceremony)..."

echo "   Signing with @scott (${SCOTT_KEY})..."
gpg --batch --yes --local-user "${SCOTT_KEY}" --sign-key "${OSTK_KEY}" 2>/dev/null && \
  echo "   ✓ @scott certified ${OSTK_KEY}" || \
  echo "   ⚠ @scott key not available — sign manually: gpg --local-user ${SCOTT_KEY} --sign-key ${OSTK_KEY}"

echo "   Signing with @haystack.prime (${KERNEL_KEY})..."
gpg --batch --yes --local-user "${KERNEL_KEY}" --sign-key "${OSTK_KEY}" 2>/dev/null && \
  echo "   ✓ @haystack.prime certified ${OSTK_KEY}" || \
  echo "   ⚠ kernel key not available — sign manually: gpg --local-user ${KERNEL_KEY} --sign-key ${OSTK_KEY}"

echo ""
echo "   @ostk.ai MINTED: ${OSTK_KEY}"
echo "   Lineage: ${SCOTT_KEY} + ${KERNEL_KEY} → ${OSTK_KEY}"
echo ""

# ── Step 4: Upload public key to @ostk.ai GitHub account ──────────────────────

echo "4. Uploading @ostk.ai public key to GitHub..."
ARMORED_KEY=$(gpg --armor --export "${OSTK_KEY}")

UPLOAD_RESULT=$(curl -fsSL -X POST \
  -H "Authorization: Bearer ${OSTK_TOKEN}" \
  -H "Content-Type: application/json" \
  https://api.github.com/user/gpg_keys \
  -d "{\"armored_public_key\": $(echo "${ARMORED_KEY}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
  2>&1)

if echo "${UPLOAD_RESULT}" | python3 -c "import json,sys; d=json.load(sys.stdin); print('key_id:',d.get('key_id','?'))" 2>/dev/null | grep -q "key_id:"; then
  echo "   ✓ GPG key uploaded to @${GH_USER} GitHub account"
  echo "   GitHub will now show @${GH_USER} as 'Verified' on commits signed with ${OSTK_KEY}"
else
  echo "   ⚠ Upload may have failed (key may already exist)"
  echo "   Check: https://github.com/settings/keys"
fi
echo ""

# ── Step 5: Export public key to prime.asc ────────────────────────────────────

echo "5. Exporting prime.asc..."
gpg --armor --export "${OSTK_KEY}" > "${REPO_DIR}/prime.asc"
echo "   ✓ Written: prime.asc"
echo ""

# ── Step 6: Update KEYS with @ostk.ai fingerprint ─────────────────────────────

echo "6. Updating KEYS file..."
KEYS_FILE="${REPO_DIR}/KEYS"
# Replace the ceremony placeholder line
if grep -q "CEREMONY PLACEHOLDER\|TO BE FILLED" "${KEYS_FILE}" 2>/dev/null; then
  python3 - <<PYEOF
import re
with open("${KEYS_FILE}") as f:
    content = f.read()
content = re.sub(
    r'\[TO BE FILLED BY @ostk\.ai\.prime CEREMONY\]',
    "${OSTK_KEY}",
    content
)
with open("${KEYS_FILE}", 'w') as f:
    f.write(content)
print("   ✓ KEYS updated with fingerprint: ${OSTK_KEY}")
PYEOF
else
  echo "   KEYS already has fingerprint or needs manual update"
fi
echo ""

# ── Step 7: Sign genesis commit as @ostk.ai ───────────────────────────────────

echo "7. Signing genesis commit as @ostk.ai..."
cd "${REPO_DIR}"

git config user.email "${OSTK_EMAIL}"
git config user.name "${OSTK_NAME}"
git config user.signingkey "${OSTK_KEY}"

# Stage the updated KEYS + prime.asc
git add KEYS prime.asc
git commit --amend --gpg-sign --local-user "${OSTK_KEY}" -C HEAD

SIGNED_SHA=$(git log --oneline -1 | cut -d' ' -f1)
echo "   ✓ Genesis commit signed: ${SIGNED_SHA}"

# Verify
git log --show-signature -1 | grep -E "Good signature|BAD signature|sig" | head -3
echo ""

# ── Step 8: Push as @ostk.ai ──────────────────────────────────────────────────

echo "8. Pushing as @ostk.ai..."
GIT_ASKPASS="" GH_TOKEN="${OSTK_TOKEN}" git push --force-with-lease \
  "https://${GH_USER}:${OSTK_TOKEN}@github.com/os-tack/ostk.ai.git" main

echo "   ✓ Pushed: https://github.com/os-tack/ostk.ai"
echo ""

# ── Record the ceremony in haystack audit ─────────────────────────────────────

haystack needle add "@ostk.ai minted — ceremony complete, genesis signed by ${OSTK_KEY}" --priority P0 2>/dev/null || true

echo "=== CEREMONY COMPLETE ==="
echo ""
echo "  @ostk.ai.prime: ${OSTK_KEY}"
echo "  Certified by:   ${SCOTT_KEY} + ${KERNEL_KEY}"
echo "  Genesis commit: ${SIGNED_SHA}"
echo "  Repository:     https://github.com/os-tack/ostk.ai"
echo ""
echo "Next: tag v1.1 on haystack repo, then nudge proof-of-life"
