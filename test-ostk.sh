#!/usr/bin/env sh
set -eu

# test-ostk.sh — integration tests for ostk + haystack

PASS=0
FAIL=0
TOTAL=0

assert() {
  TOTAL=$((TOTAL + 1))
  desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    echo "  ok  ${desc}"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL ${desc}"
  fi
}

assert_fail() {
  TOTAL=$((TOTAL + 1))
  desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    echo "  FAIL ${desc} (expected failure, got success)"
  else
    PASS=$((PASS + 1))
    echo "  ok  ${desc}"
  fi
}

assert_contains() {
  TOTAL=$((TOTAL + 1))
  desc="$1"; expected="$2"; shift 2
  output=$("$@" 2>&1) || true
  if echo "$output" | grep -q "$expected"; then
    PASS=$((PASS + 1))
    echo "  ok  ${desc}"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL ${desc} (expected '${expected}' not found)"
  fi
}

cleanup() {
  # Kill any leftover listener
  [ -f .haystack/pid ] && kill "$(cat .haystack/pid)" 2>/dev/null || true
  rm -f .haystack/sock .haystack/reply .haystack/pid
  rm -rf /tmp/ostk-test-*
}

trap cleanup EXIT

OSTK="./ostk"
HAYSTACK="./haystack"
export PATH=".:$PATH"

echo "=== haystack unit tests ==="

assert "haystack --version" sh "$HAYSTACK" --version
assert_contains "haystack version string" "haystack" sh "$HAYSTACK" --version
assert_contains "haystack help" "compile" sh "$HAYSTACK" help
assert "haystack boot (no negotiate)" sh "$HAYSTACK" boot

echo ""
echo "=== ostk boot + negotiate tests ==="

export OSTK_DIR="/tmp/ostk-test-t1"
rm -rf "$OSTK_DIR"
assert "ostk boot (T1 agent)" sh "$OSTK" boot
assert_contains "session has identity" "identity=" cat "$OSTK_DIR/state/session"
assert_contains "session has tier" "tier=T1" cat "$OSTK_DIR/state/session"
assert_contains "session is bound" "bound=true" cat "$OSTK_DIR/state/session"
assert_contains "kernel reply exists" "status=ACK" cat "$OSTK_DIR/state/kernel"
assert_contains "kernel has nonce" "nonce=" cat "$OSTK_DIR/state/kernel"

echo ""
echo "=== identity tests ==="

assert_contains "ostk identity" "identity=" sh "$OSTK" identity
assert_contains "ostk identity --resolve" "bound=false" sh "$OSTK" identity --resolve

echo ""
echo "=== compile tests (T1, should pass) ==="

# Kill listener from boot, test direct compile
[ -f .haystack/pid ] && kill "$(cat .haystack/pid)" 2>/dev/null || true
rm -f .haystack/sock .haystack/reply .haystack/pid
assert "ostk compile (direct, no socket)" sh "$OSTK" compile
assert_contains "events logged compile" "compile" cat "$OSTK_DIR/log/events"

echo ""
echo "=== compile via socket ==="

rm -rf "$OSTK_DIR"
assert "ostk boot (starts listener)" sh "$OSTK" boot
# Small delay for listener to be ready
sleep 0.2
assert_contains "compile via socket" "compiled" sh "$OSTK" compile

echo ""
echo "=== compile.d pipeline ==="

# Kill listener, reboot, test with stages
[ -f .haystack/pid ] && kill "$(cat .haystack/pid)" 2>/dev/null || true
rm -f .haystack/sock .haystack/reply .haystack/pid
rm -rf "$OSTK_DIR"
assert "ostk boot (for pipeline)" sh "$OSTK" boot
sleep 0.2
assert_contains "compile with pipeline" "compiled" sh "$OSTK" compile

echo ""
echo "=== bench tests (T1, should pass) ==="

assert "ostk bench (direct)" sh "$OSTK" bench

echo ""
echo "=== tier enforcement tests ==="

# T2 (alias, no crypto)
export OSTK_DIR="/tmp/ostk-test-t2"
rm -rf "$OSTK_DIR"
[ -f .haystack/pid ] && kill "$(cat .haystack/pid)" 2>/dev/null || true
rm -f .haystack/sock .haystack/reply .haystack/pid
HOME="/tmp/ostk-test-t2home" GIT_CONFIG_GLOBAL="/dev/null" GIT_CONFIG_SYSTEM="/dev/null" \
  OSTK_ENTITY="visitor" sh "$OSTK" boot >/dev/null 2>&1 || true
assert_contains "T2 tier bound" "tier=T2" cat "$OSTK_DIR/state/session"
[ -f .haystack/pid ] && kill "$(cat .haystack/pid)" 2>/dev/null || true
rm -f .haystack/sock .haystack/reply .haystack/pid
assert_fail "T2 compile blocked" \
  sh -c "HOME=/tmp/ostk-test-t2home GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null OSTK_ENTITY=visitor OSTK_DIR=$OSTK_DIR sh $OSTK compile"

# T3 (anonymous)
export OSTK_DIR="/tmp/ostk-test-t3"
rm -rf "$OSTK_DIR"
HOME="/tmp/ostk-test-t3home" GIT_CONFIG_GLOBAL="/dev/null" GIT_CONFIG_SYSTEM="/dev/null" \
  sh "$OSTK" boot >/dev/null 2>&1 || true
assert_contains "T3 tier bound" "tier=T3" cat "$OSTK_DIR/state/session"
[ -f .haystack/pid ] && kill "$(cat .haystack/pid)" 2>/dev/null || true
rm -f .haystack/sock .haystack/reply .haystack/pid
assert_fail "T3 compile blocked" \
  sh -c "HOME=/tmp/ostk-test-t3home GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null OSTK_DIR=$OSTK_DIR sh $OSTK compile"

echo ""
echo "=== status + version ==="

export OSTK_DIR="/tmp/ostk-test-t1"
assert_contains "ostk version" "ostk" sh "$OSTK" version
assert_contains "ostk status" "version=" sh "$OSTK" status
assert_contains "ostk help" "boot" sh "$OSTK" help

echo ""
echo "=== results ==="
echo "${PASS}/${TOTAL} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
