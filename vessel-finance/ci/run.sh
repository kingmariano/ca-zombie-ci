#!/bin/bash
# vessel-finance custom CI job: full-history vault scan + bytecode parity check.
# Read-only, keyless RPCs only. Never prints secrets.
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out

echo "== vessel-finance custom CI =="
date -u
echo

echo "== 1) full-history vault log scan (all events, deploy block 8,015,163 -> latest) =="
python3 ci/scan.py 2>&1 | tee ci-out/scan.log
SCAN_RC=${PIPESTATUS[0]}
echo "scan exit=$SCAN_RC"
echo

echo "== 2) scroll fork RPC probe (for reference) =="
: > ci-out/fork_rpc.txt
for u in "https://scroll-rpc.publicnode.com" "https://rpc.scroll.io" "https://scroll.drpc.org"; do
  r=$(curl -s -m 15 -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$u" 2>/dev/null)
  case "$r" in
    *result*) echo "$u" >> ci-out/fork_rpc.txt; echo "working RPC found (keyless public)" ; break;;
  esac
done
echo

echo "== 3) impl bytecode parity check (informational, non-fatal) =="
python3 ci/verify_bytecode.py 2>&1 | tee ci-out/bytecode_check.txt || true
echo

echo "== done =="
exit $SCAN_RC
