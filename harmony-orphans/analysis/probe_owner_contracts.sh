#!/bin/bash
OUT=/home/heisenberg/CA/harmony-orphans/analysis/owner_created_probe.jsonl
RPC=https://api.harmony.one
: > "$OUT"
jq -r '.[].addr' /home/heisenberg/CA/harmony-orphans/analysis/owner_creations.json | while read -r A; do
  CODE=$(timeout 25 cast code "$A" --rpc-url $RPC 2>/dev/null)
  SZ=$(( ${#CODE} / 2 ))
  NAME=$(timeout 25 cast call "$A" 'name()(string)' --rpc-url $RPC 2>/dev/null)
  SYM=$(timeout 25 cast call "$A" 'symbol()(string)' --rpc-url $RPC 2>/dev/null)
  BAL=$(timeout 25 cast balance "$A" --rpc-url $RPC 2>/dev/null)
  OWNER=""
  if [ -n "$NAME" ] || [ -n "$SYM" ]; then
    OWNER=$(timeout 25 cast call "$A" 'owner()(address)' --rpc-url $RPC 2>/dev/null)
  fi
  jq -cn --arg a "$A" --argjson sz "$SZ" --arg n "$NAME" --arg s "$SYM" --arg o "$OWNER" --arg b "$BAL" \
    '{addr:$a, code_bytes:$sz, name:$n, symbol:$s, owner:$o, balance_wei:$b}' >> "$OUT"
  echo "done $A" >&2
done
echo "PROBE COMPLETE" >> "$OUT"
