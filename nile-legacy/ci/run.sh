#!/usr/bin/env bash
# Heavy job for nile-legacy: refresh live-state scans on Linea via keyless public RPC.
# Writes results to ci-out/ (uploaded as CI artifact). No secrets are written anywhere.
set -uo pipefail
cd "$(dirname "$0")/.."   # -> nile-legacy/
mkdir -p ci-out

RPC="${LINEA_RPC_URL:-https://rpc.linea.build}"
export LINEA_RPC_URL="$RPC"

BLOCK=$(curl -s -m 25 -X POST -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$RPC" \
  | python3 -c "import json,sys;print(int(json.load(sys.stdin)['result'],16))")
echo "linea block: $BLOCK" | tee ci-out/block.txt

run() {
  local name="$1"; shift
  for i in 1 2 3; do
    if python3 "$@"; then return 0; fi
    echo "[ci] retry $i for $name"; sleep 5
  done
  echo "[ci] FAILED $name"; return 1
}

rc=0
run pairs   analysis/scan_pairs.py        || rc=1
run gauges  analysis/scan_gauges.py       || rc=1
run stable  analysis/scan_stable_quotes.py || rc=1
run quotes  analysis/quotes.py            || rc=1
if [ -n "${ETHERSCANV2_API_KEY:-}" ]; then
  run stakers analysis/lp_stakers.py      || rc=1
else
  echo "[ci] ETHERSCANV2_API_KEY missing; skipping staker reconstruction"
fi

for f in pair_scan gauge_scan stable_quote_scan quotes_top_pair lp_stakers; do
  [ -f "analysis/$f.json" ] && cp "analysis/$f.json" ci-out/
done
cp analysis/pair_a9a1_code.hex ci-out/ 2>/dev/null || true

echo "[ci] ci-out contents:"; ls -la ci-out/
exit $rc
