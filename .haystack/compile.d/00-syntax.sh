#!/usr/bin/env sh
# Verify ostk and haystack parse without syntax errors
for f in ostk haystack; do
  if [ -f "$f" ]; then
    sh -n "$f" 2>&1 || { echo "syntax error: $f"; exit 1; }
  fi
done
echo "ok"
