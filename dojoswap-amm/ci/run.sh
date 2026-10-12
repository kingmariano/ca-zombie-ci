#!/usr/bin/env bash
# ci/run.sh — dojoswap-amm heavy job (public CI repo; NO secrets in this file).
#
# Lean run: deployed-wasm guard checks (locker + factory) + published-source PoC
# + independent live re-enumeration.  (The full reproducible-build check of the
# dojoswap workspace ran in CI run 38184454300; its results are archived in
# ci-artifacts/.)
# Outputs -> ci-out/
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
OUT=ci-out

echo "=== [1] published-source locker PoC (cw-multitest; historical) ==="
if [ -d poc/locker-poc ]; then
  ( cd poc/locker-poc && timeout 900 cargo test --test exploit -- --nocapture ) > "$OUT/locker-poc.log" 2>&1
  echo "poc rc=$?" >> "$OUT/locker-poc.log"
fi

echo "=== [2] DECISIVE: deployed wasm in cosmwasm-vm ==="
if [ -d poc/wasm-harness ]; then
  ( cd poc/wasm-harness && timeout 1500 cargo run --release --bin wasm-harness ) > "$OUT/locker-deployed-harness.log" 2>&1
  echo "harness rc=$?" >> "$OUT/locker-deployed-harness.log"
  ( cd poc/wasm-harness && timeout 1500 cargo run --release --bin factory_check ) > "$OUT/factory-guard-check.log" 2>&1
  echo "factory rc=$?" >> "$OUT/factory-guard-check.log"
fi

echo "=== [3] live re-enumeration ==="
python3 analysis/enumerate.py > "$OUT/enum.log" 2>&1 || echo "enumeration failed" >> "$OUT/enum.log"
cp -f analysis/pairs-live.json "$OUT/pairs-live.json" 2>/dev/null || true
python3 analysis/locker_scan.py > "$OUT/locker-scan.log" 2>&1 || true
cp -f analysis/locker-locks.json "$OUT/locker-locks.json" 2>/dev/null || true

echo "=== summary ==="
echo "--- historical PoC (published source, NOT deployed) ---"
grep -E "test result|attacker_claims|end_to_end" "$OUT/locker-poc.log" 2>/dev/null | tail -5
echo "--- DECISIVE deployed locker wasm ---"
grep -E "UNSTAKE|positive control|lock OK|wasm loaded" "$OUT/locker-deployed-harness.log" 2>/dev/null | tail -6
echo "--- deployed factory guards ---"
grep -E "migrate_pair|admin_withdraw|set_whitelist|instantiate OK" "$OUT/factory-guard-check.log" 2>/dev/null | tail -6
echo "--- live enumeration ---"
tail -3 "$OUT/enum.log" 2>/dev/null
echo "--- locker locks (H-O, not E-U) ---"
tail -3 "$OUT/locker-scan.log" 2>/dev/null
