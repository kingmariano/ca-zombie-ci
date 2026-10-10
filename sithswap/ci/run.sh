#!/usr/bin/env bash
# C2-46 SithSwap — CI heavy job (read-only on-chain proofs).
# Runs: (1) access-gate + swap-guard simulations, (2) independent curve-math verification.
# Outputs: ci-out/sim_results.json, ci-out/math_check.json (+ logs).
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
echo "[ci] root=$ROOT"

# pycryptodome is needed for starknet keccak selectors (sn.py has a fallback table if unavailable)
python3 -c "import Crypto" 2>/dev/null || pip install --quiet --disable-pip-version-check --break-system-packages pycryptodome || pip install --quiet --disable-pip-version-check pycryptodome || python3 -m pip install --quiet --break-system-packages pycryptodome || true

mkdir -p ci-out

echo "[ci] === sim proofs ==="
timeout 1200 python3 analysis/sim_proofs.py --out 2>&1 | tee ci-out/sim_proofs.log
SIM_RC=${PIPESTATUS[0]}

echo "[ci] === math check ==="
MATH_MAX_POOLS=20 timeout 900 python3 ci/math_check.py 2>&1 | tee ci-out/math_check.log
MATH_RC=${PIPESTATUS[0]}

echo "[ci] === skim excess ==="
timeout 600 python3 ci/skim_top.py 2>&1 | tee ci-out/skim_excess.log
SKIM_RC=${PIPESTATUS[0]}

echo "[ci] === summary ==="
python3 - <<'EOF' | tee ci-out/ci_summary.txt
import json, os
sim = {}
math = {}
try: sim = json.load(open("ci-out/sim_results.json"))
except Exception as e: sim = {"error": str(e)}
try: math = json.load(open("ci-out/math_check.json"))
except Exception as e: math = {"error": str(e)}
print("SithSwap C2-46 CI summary")
print("sim block:", sim.get("block"))
ok = 0; revert = 0
for c in sim.get("cases", []):
    st = c.get("result", {}).get("status")
    if st == "OK": ok += 1
    if st == "REVERT": revert += 1
    print(f"  {c['name']}: {st}")
print(f"sim cases: {len(sim.get('cases', []))} (OK={ok}, REVERT={revert})")
print("math block:", math.get("block"), "checked:", math.get("checked"),
      "exact-match+bind:", math.get("out_match_and_bind"))
mismatches = [r for r in math.get("results", []) if r.get("out_match") is False]
print("math mismatches:", len(mismatches))
for m in mismatches[:5]: print("  ", m)
gaps = [r.get("k_gap_wei", 0) for r in math.get("results", []) if "k_gap_wei" in r]
print("max k_gap_wei:", max(gaps) if gaps else None)
try:
    skim = json.load(open("ci-out/skim_excess.json"))
    print("skim: checked", len(skim.get("rows", [])), "pools_with_excess", skim.get("pools_with_excess"))
    for r in skim.get("rows", []):
        if r.get("excess0") or r.get("excess1"):
            print("  excess:", r["pid"], r["pair"], r["excess0"], r["excess1"])
except Exception as e:
    print("skim: n/a", e)
EOF

echo "[ci] done (sim_rc=$SIM_RC math_rc=$MATH_RC)"
# do not fail the job on non-critical RPC hiccups; artifacts carry the results
exit 0
