#!/usr/bin/env bash
# BlueMove Phase-2 CI job: full pool + escrow enumeration + live gating simulations.
# Read-only; public Sui endpoints only; no secrets.
set -euo pipefail
echo "[bluemove] python: $(python3 --version)"
cd "$(dirname "$0")/.."
echo "== full enumeration =="
OUT_DIR=ci-out WORKERS=12 python3 ci/scan_bluemove.py
echo "== live gating simulations =="
OUT_DIR=ci-out python3 ci/sim_poc.py
echo "== summary =="
python3 - <<'PY'
import json
s = json.load(open("ci-out/bluemove_state.json"))
print(json.dumps({"checkpoint": s.get("checkpoint"), "counts": s.get("counts"),
                  "usd_totals": s.get("usd_totals"), "extractable_usd": s.get("extractable_usd")}, indent=1))
r = json.load(open("ci-out/sim/sim_results.json"))
for x in r["results"]:
    print(x.get("name"), x.get("status"), x.get("abortCode"), (x.get("error") or "")[:120])
PY
echo "[bluemove] done"
ls -la ci-out/ ci-out/sim/ | head -30
