#!/usr/bin/env bash
# lift-keys-to-bw.sh — export GPG keys from disk and store in Bitwarden
#
# Lifts the following keys into the Bitwarden folder:
#   955AF54E  @scott (human root key)
#   99B076C9  @haystack.prime (kernel key)
#   A7B7...   @haystack.prime.ci (CI signing key)
#   6C31...   @ostk.ai (minted key)
#
# Requires: bw CLI logged in and unlocked
# Run: BW_SESSION=$(bw unlock --raw) bash lift-keys-to-bw.sh

set -euo pipefail

BW_FOLDER_ID="9b6e38cd-72f4-4a65-bf27-b40a012f2000"

KEYS=(
  "6AD753BD98030BB8225D3550955AF54E2E5E5F71:scott-gpg-955AF54E:@scott human root key"
  "99B076C9AE6B889A2B7CD88B42E499C6D4889BFC:haystack-prime-gpg-99B076C9:@haystack.prime kernel key"
  "A7B7385963250149C836389BC78631AA6893C46C:haystack-prime-ci-gpg-A7B7:@haystack.prime.ci signing key"
  "6C31536F3DC1BD4780E87B7780DD42208FE25413:ostk-ai-gpg-6C31:@ostk.ai root key — minted v1.1"
)

echo "=== lift-keys-to-bw ==="
echo "Exporting GPG keys to Bitwarden folder: ${BW_FOLDER_ID}"
echo ""

if ! bw status | grep -q '"status":"unlocked"' 2>/dev/null; then
  echo "ERROR: Bitwarden is not unlocked."
  echo "Run: export BW_SESSION=\$(bw unlock --raw)"
  echo "Then re-run this script."
  exit 1
fi

for ENTRY in "${KEYS[@]}"; do
  IFS=: read -r FINGERPRINT NAME DESCRIPTION <<< "$ENTRY"

  echo "Processing: ${NAME} (${FINGERPRINT:0:16}...)"

  # Export secret key
  ARMORED=$(gpg --armor --export-secret-keys "${FINGERPRINT}" 2>/dev/null)
  if [ -z "$ARMORED" ]; then
    echo "  ⚠ key ${FINGERPRINT:0:16} not found on disk — skipping"
    continue
  fi

  # Export public key too (append to the note)
  PUBKEY=$(gpg --armor --export "${FINGERPRINT}" 2>/dev/null)

  NOTE="# ${DESCRIPTION}
# Fingerprint: ${FINGERPRINT}
# Exported: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# WARNING: This is a private key. Handle with care.

## Private Key
${ARMORED}

## Public Key
${PUBKEY}"

  # Check if item already exists
  EXISTING=$(bw list items --search "${NAME}" --session "${BW_SESSION:-}" 2>/dev/null | \
    python3 -c "import json,sys; items=json.load(sys.stdin); print(items[0]['id'] if items else '')" 2>/dev/null || echo "")

  if [ -n "$EXISTING" ]; then
    echo "  Item already exists (${EXISTING}) — updating..."
    bw get item "${EXISTING}" --session "${BW_SESSION:-}" | \
      python3 -c "
import json, sys
item = json.load(sys.stdin)
item['notes'] = sys.argv[1]
print(json.dumps(item))
" "${NOTE}" | bw encode | bw edit item "${EXISTING}" --session "${BW_SESSION:-}" > /dev/null
    echo "  ✓ Updated: ${NAME} → bw item ${EXISTING}"
  else
    echo "  Creating new vault item..."
    ITEM_ID=$(bw get template item --session "${BW_SESSION:-}" | python3 -c "
import json, sys
t = json.load(sys.stdin)
t['name'] = sys.argv[1]
t['type'] = 2  # secure note
t['folderId'] = sys.argv[2]
t['notes'] = sys.argv[3]
print(json.dumps(t))
" "${NAME}" "${BW_FOLDER_ID}" "${NOTE}" | bw encode | bw create item --session "${BW_SESSION:-}" | \
      python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
    echo "  ✓ Created: ${NAME} → bw item ${ITEM_ID}"
  fi
  echo ""
done

echo "=== Done ==="
echo ""
echo "To retrieve a key later:"
echo "  bw get item <item-id> | jq -r '.notes' | grep -A9999 'BEGIN PGP' | gpg --import"
echo ""
echo "Or use the bitwarden-secrets agent in haystack to fetch and import automatically."
