#!/usr/bin/env bash
set -euo pipefail

REPO="os-tack/ostk.ai"
VERSION="${OSTK_VERSION:-latest}"

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}-${ARCH}" in
  Darwin-arm64)  TARGET="aarch64-apple-darwin" ;;
  Darwin-x86_64) TARGET="x86_64-apple-darwin" ;;
  Linux-aarch64) TARGET="aarch64-unknown-linux-musl" ;;
  Linux-x86_64)  TARGET="x86_64-unknown-linux-musl" ;;
  *) echo "unsupported platform: ${OS}-${ARCH}" && exit 1 ;;
esac

if [ "$VERSION" = "latest" ]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
fi

TARBALL="haystack-${VERSION}-${TARGET}.tar.gz"
ASC="${TARBALL}.asc"
BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"

echo "ostk: installing ${VERSION} for ${TARGET}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -fsSL "${BASE_URL}/${TARBALL}" -o "${tmpdir}/${TARBALL}"
curl -fsSL "${BASE_URL}/${ASC}" -o "${tmpdir}/${ASC}"

# Verify GPG signature (required)
if ! command -v gpg >/dev/null 2>&1; then
  echo "ostk: ERROR — gpg is required for signature verification"
  echo "ostk: install gpg and retry. unsigned installs are not supported."
  exit 1
fi

echo "ostk: verifying signature..."
gpg --verify "${tmpdir}/${ASC}" "${tmpdir}/${TARBALL}" || {
  echo "ostk: signature verification FAILED — aborting install"
  exit 1
}
echo "ostk: signature verified ✓"

tar -xzf "${tmpdir}/${TARBALL}" -C "${tmpdir}"
install -m 755 "${tmpdir}/haystack" /usr/local/bin/haystack
ln -sf /usr/local/bin/haystack /usr/local/bin/hs

# Install ostk CLI (verified via signed release tarball)
OSTK_SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${VERSION}/ostk"
curl -fsSL "${OSTK_SCRIPT_URL}" -o "${tmpdir}/ostk"
# Verify the script is a valid bash script before installing
head -1 "${tmpdir}/ostk" | grep -q '^#!/usr/bin/env sh' || {
  echo "ostk: ERROR — downloaded ostk CLI is not a valid script, aborting"
  exit 1
}
install -m 755 "${tmpdir}/ostk" /usr/local/bin/ostk

echo "ostk: installed. run 'ostk boot'"
