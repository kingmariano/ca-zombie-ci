#!/usr/bin/env python3
"""Compute health factors for Ironclad borrowers + treasury aToken balances (read-only)."""
import json, sys
sys.path.insert(0, "/home/heisenberg/CA/ironclad-finance/analysis")
from dump_state import rpc_batch, sel, dec, POOL
from eth_abi import encode as abi_encode

h = json.load(open("/home/heisenberg/CA/ironclad-finance/analysis/holders.json"))
st = json.load(open("/home/heisenberg/CA/ironclad-finance/analysis/state_dump.json"))
TREASURY = "0xd93E25A8B1D645b15f8c736E1419b4819Ff9e6EF"

# unique top borrowers
borrowers = {}
for key, v in h.items():
    if not key.endswith("vDebt"):
        continue
    sym = key.split(":")[0]
    for it in v["holders"][:15]:
        borrowers.setdefault(it["address"], []).append((sym, it["value"]))
print(f"unique borrowers (top40/market): {len(borrowers)}", flush=True)

addrs = list(borrowers.keys())
calls = [(POOL, sel("getUserAccountData(address)") + abi_encode(["address"], [a]).hex()) for a in addrs]
res = rpc_batch(calls)
out = {}
ok = 0
for a, r in zip(addrs, res):
    if isinstance(r, str) and r.startswith("0x") and len(r) > 2:
        try:
            v = dec(["uint256"]*6, r)
            out[a] = {"collateral": str(v[0]), "debt": str(v[1]), "available": str(v[2]),
                      "liqThreshold": v[3], "ltv": v[4], "hf": str(v[5]), "markets": borrowers[a]}
            ok += 1
        except Exception as e:
            out[a] = {"error": f"decode {e}", "markets": borrowers[a]}
    else:
        out[a] = {"error": "revert (likely MODE oracle missing)", "markets": borrowers[a]}
print(f"decoded: {ok}/{len(addrs)}", flush=True)

# treasury aToken balances
toks = [(e["symbol"], e["aToken"]) for e in st["reserves"].values() if e["aToken"]]
calls2 = [(t, sel("balanceOf(address)") + abi_encode(["address"], [TREASURY]).hex()) for _, t in toks]
res2 = rpc_batch(calls2)
treasury = {}
for (sym, t), r in zip(toks, res2):
    try:
        v = dec(["uint256"], r)
        treasury[sym] = str(v[0]) if v else None
    except Exception:
        treasury[sym] = None

json.dump({"borrowers": out, "treasury_aTokens": treasury}, open("/home/heisenberg/CA/ironclad-finance/analysis/borrowers_hf.json", "w"), indent=1)

# summary
print("\n== borrowers with HF data (sorted by HF) ==")
rows = [(a, d) for a, d in out.items() if "hf" in d]
def f(x): return int(x) / 1e18
rows.sort(key=lambda x: f(x[1]["hf"]))
for a, d in rows[:25]:
    mk = ",".join(m for m, _ in d["markets"][:3])
    print(f'{a} HF={f(d["hf"]):.4f} coll=${int(d["collateral"])/1e18:,.0f} debt=${int(d["debt"])/1e18:,.0f} [{mk}]')
errs = [a for a, d in out.items() if "error" in d]
print(f"\nerrors: {len(errs)} (top {errs[:3]})")
print("\n== treasury aToken balances ==")
for sym, v in treasury.items():
    if v and int(v) > 0:
        print(sym, v)
