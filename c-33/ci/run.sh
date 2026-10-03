#!/usr/bin/env bash
# C-33 heavy job: full Compound-v2 fork exposure scan (read-only JSON-RPC).
# Runs from the c-33/ folder. Results -> ci-out/ (uploaded as artifact).
set -uo pipefail
cd "$(dirname "$0")/.."
mkdir -p ci-out
echo "[c-33] python: $(python3 --version 2>&1)"
echo "[c-33] targets: $(python3 -c "import json;print(len(json.load(open('analysis/targets.json'))['targets']))")"
python3 ci/scan.py 2>&1 | tee ci-out/scan.log
echo "[c-33] scan exit: ${PIPESTATUS[0]}"
ls -la ci-out/ || true
python3 - <<'PY'
import json
try:
    s = json.load(open("ci-out/scan_summary.json"))
    print("[c-33] SUMMARY")
    for k in ("targets","chains_scanned","chains_no_rpc","markets_total","empty_markets",
              "tiny_markets","empty_borrow_attack_markets","direct_drain_markets"):
        print(f"[c-33]   {k}: {s.get(k)}")
    print("[c-33] status_counts:", json.dumps(s.get("status_counts", {})))
    print("[c-33] top exposure:")
    for e in s.get("exposure", [])[:20]:
        print(f"[c-33]   {e.get('potentialUSD'):>16,.2f}  {e.get('mode'):26s} {e.get('protocol'):26s} {e.get('chain')}")
except Exception as exc:
    print("[c-33] summary read failed:", exc)
PY
