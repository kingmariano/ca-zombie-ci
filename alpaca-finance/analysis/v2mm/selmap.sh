#!/bin/bash
# Extract function selectors from a solidity file (simple regex; handles multiline signatures)
f=$1
awk 'BEGIN{IGNORECASE=0}
/function /{buf=$0; while (buf !~ /\{/ && buf !~ /;/ && (getline line) > 0) {buf=buf line}; print buf}
' "$f" | sed 's/^[[:space:]]*//' | grep -oP 'function\s+\K[a-zA-Z0-9_]+\([^)]*\)' | while read -r sig; do
  norm=$(echo "$sig" | sed 's/^[a-zA-Z0-9_]*//')  # keep (args)
  name=$(echo "$sig" | sed 's/(.*//')
  # map common types
  args=$(echo "$norm" | tr -d ' ')
  args=$(echo "$args" | sed -E 's/uint[0-9]*/uint256/g; s/int[0-9]*/int256/g; s/\[[0-9]*\]/[]/g')
  full="${name}${args}"
  cast sig "$full" 2>/dev/null
done
