#!/usr/bin/env bash
# Probe dataSize distribution of accounts owned by Cega V1 Solana program.
# READ-ONLY RPC calls. Rate-limit friendly.
set -u
RPC="${RPC:-https://api.mainnet-beta.solana.com}"
PROG="3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs"
OUT="${OUT:-/home/heisenberg/CA/cega-v1/analysis/solana/size_probe.json}"
echo '{}' > "$OUT.tmp"

probe() {
  local size="$1"
  local resp
  resp=$(curl -s -m 30 "$RPC" -H 'Content-Type: application/json' -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getProgramAccounts\",\"params\":[\"$PROG\",{\"encoding\":\"base64\",\"dataSlice\":{\"offset\":0,\"length\":0},\"filters\":[{\"dataSize\":$size}]}]}")
  local n
  n=$(echo "$resp" | jq -r 'if .result then (.result|length) else "ERR" end' 2>/dev/null)
  echo "$size $n"
  if [ "$n" != "ERR" ] && [ "$n" != "0" ]; then
    echo "$resp" | jq --arg s "$size" -c '{($s): [.result[].pubkey]}' >> "$OUT.tmp"
  fi
}

for s in $(seq 40 4 400); do probe "$s"; sleep 0.55; done
for s in 512 600 776 1000 1024 2048 4096; do probe "$s"; sleep 0.55; done
jq -s 'add' "$OUT.tmp" > "$OUT"
rm -f "$OUT.tmp"
echo "DONE -> $OUT"
