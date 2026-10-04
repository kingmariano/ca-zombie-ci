#!/usr/bin/env bash
# Read-only Balancer V2 chain scanner runner (polygon, gnosis, avalanche).
# Reads ETHERSCANV2_API_KEY from /home/heisenberg/CA/.env at runtime; never prints it.
set -u
cd /home/heisenberg/CA/balancer-v2

export ETHERSCANV2_API_KEY="$(python3 - <<'PY'
import re
raw = open('/home/heisenberg/CA/.env').read()
m = re.search(r'^ETHERSCANV2_API_KEY=(.*)$', raw, re.M)
v = (m.group(1).strip() if m else '')
if len(v) >= 2 and v[0] in ('"', "'") and v[-1] == v[0]:
    v = v[1:-1]
print(v)
PY
)"
if [ -z "${ETHERSCANV2_API_KEY:-}" ]; then
  echo "FATAL: no API key loaded"
  exit 1
fi
echo "API key loaded: yes (not printed)"

run_one() {
  local chain="$1" chainid="$2"; shift 2
  local rpc
  for rpc in "$@"; do
    echo "[$chain] attempt rpc=$rpc"
    rm -f "analysis/chain-$chain.json"
    if python3 analysis/scan_chain.py --chain "$chain" --chainid "$chainid" --rpc "$rpc" \
        --vault 0xBA12222222228d8Ba445958a75a0704d566BF2C8 \
        --out "analysis/chain-$chain.json" 2>&1; then
      if [ -s "analysis/chain-$chain.json" ]; then
        echo "[$chain] OK with $rpc"
        return 0
      fi
    fi
    echo "[$chain] failed with $rpc, trying next"
  done
  echo "[$chain] ALL RPCS FAILED"
  return 1
}

run_one polygon 137 https://polygon-bor-rpc.publicnode.com https://polygon-rpc.com
run_one gnosis 100 https://gnosis-rpc.publicnode.com https://rpc.gnosischain.com
run_one avalanche 43114 https://api.avax.network/ext/bc/C/rpc https://avalanche-c-chain-rpc.publicnode.com
echo "ALL DONE"
