#!/usr/bin/env bash
# CI heavy job for C2-49 Haiko (Starknet). Read-only on-chain data collection.
# Writes results to ci-out/. Uses keyless public RPCs (no secrets needed/printed).
set -uo pipefail
cd "$(dirname "$0")/.."   # haiko/
OUT=ci-out
mkdir -p "$OUT"
echo "=== Haiko C2-49 heavy job — $(date -u +%FT%TZ)"
echo "python: $(python3 --version 2>&1)"

run_step () {
  local name="$1"; shift
  echo "--- step: $name"
  if "$@" > "$OUT/$name.log" 2>&1; then
    echo "    OK: $name"
  else
    echo "    FAIL($?): $name (see $OUT/$name.log)"
    tail -5 "$OUT/$name.log" || true
  fi
}

# 0) deps: keccak for starknet selectors (runner has no pycryptodome)
python3 -m pip install --quiet pycryptodome > "$OUT/pip.log" 2>&1 \
  || python3 -m pip install --quiet --user pycryptodome >> "$OUT/pip.log" 2>&1 \
  || python3 -m pip install --quiet pysha3 >> "$OUT/pip.log" 2>&1 \
  || echo "pip install failed (see pip.log)"
python3 - <<'PYEOF' > "$OUT/selcheck.log" 2>&1
import sys; sys.path.insert(0, "analysis")
from starknet_rpc import selector_from_name
print("balanceOf selector:", selector_from_name("balanceOf"))
PYEOF
cat "$OUT/selcheck.log"

# 0b) connectivity
python3 analysis/starknet_rpc.py > "$OUT/block.log" 2>&1 && cat "$OUT/block.log" || echo "rpc check failed"

# 1) proofs first (most important; independent of long scans)
run_step proofs python3 analysis/ci_starknet_proofs.py

# 2) full live state dump (balances, reserves, positions, views)
run_step state_dump python3 analysis/fetch_state.py
run_step deep_state python3 analysis/fetch_deep_state.py
run_step market_state python3 analysis/fetch_market_state.py

# 3) event scans (deposits/withdraws per market, create-market, mints, sweeps)
run_step scan_events python3 analysis/ci_scan_events.py

# 4) share-accounting verification (TOB-SPH-19/20 detection)
run_step share_check python3 analysis/ci_share_check.py

echo "=== outputs:"
ls -la "$OUT"
echo "=== done $(date -u +%FT%TZ)"
