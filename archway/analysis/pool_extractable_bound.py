#!/usr/bin/env python3
"""Supplementary: swap-extractable (pool-only) bound for the CWA-2026-006 mint-and-dump path.

Reads a ci-out directory (default: the final CI run artifacts) and sums the USD value of
stablecoin ("hard") and major assets held by pool-like contracts only:
  - astrovault *-pool contracts (excluding lp-token/staking/lockup/multisig/distributor)
  - bolt-market-* contracts
  - balanced / liquid.finance.swap|looping / pampit market contracts
plus the other-side value of the Osmosis ARCH GAMM pools.

Usage: python3 analysis/pool_extractable_bound.py [ci-out-dir]
"""
import json, os, sys, urllib.request, concurrent.futures as cf

D = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "ci-artifacts", "result-archway-run2", "ci-out")
LCD = "https://api.mainnet.archway.io"

def load(n):
    with open(os.path.join(D, n)) as f:
        return json.load(f)

def get(u):
    for _ in range(3):
        try:
            with urllib.request.urlopen(u, timeout=25) as r:
                return json.load(r)
        except Exception:
            pass
    return {}

bals = load("contract_balances.json")
infos = load("contract_infos.json")
model = load("model.json")
osmo = load("osmosis_pools.json")
P = model["prices"]
ARCH, OSMO, ATOM = P["ARCH"], P["OSMO"], P["ATOM"]
extra = P.get("extra", {})
USDC = P.get("USDC", 1.0)

def poolish(lab):
    lab = (lab or "").lower()
    if lab.startswith("astrovault"):
        return ("pool" in lab) and not any(x in lab for x in
                ("lp", "staking", "lockup", "multisig", "distributor"))
    return any(x in lab for x in ("bolt-market", "balanced", "liquid.finance.swap",
                                  "liquid.finance.looping", "pampit market"))

pools = [a for a, i in infos.items() if poolish(i.get("label"))]
denoms = sorted({b["denom"] for a in pools for b in bals.get(a, [])})

def trace(d):
    if not d.startswith("ibc/"):
        return d, d
    x = get(f"{LCD}/ibc/apps/transfer/v1/denom_traces/{d[4:]}")
    return d, (x.get("denom_trace") or {}).get("base_denom", "")

base = {}
with cf.ThreadPoolExecutor(12) as ex:
    for d, b in ex.map(trace, denoms):
        base[d] = b

HARD = {"uusdc": USDC, "uusdt": 1.0, "usdc": 1.0, "usdt": 1.0}
MAJOR = {"uatom": ATOM, "uosmo": OSMO, "inj": extra.get("inj"), "uakt": extra.get("uakt"),
         "utia": extra.get("utia"), "weth-wei": extra.get("weth-wei"),
         "wbtc-osmo": extra.get("wbtc")}

def usd(d, amt):
    b = base.get(d, d)
    if d == "aarch":
        return amt / 1e18 * ARCH, "arch"
    if b in HARD:
        return amt / 1e6 * HARD[b], "hard"
    if b in MAJOR and MAJOR[b]:
        dec = 18 if b in ("inj", "weth-wei") else (8 if "wbtc" in b else 6)
        return amt / 10 ** dec * MAJOR[b], "major"
    return None, "longtail:" + b

tot = {"arch": 0.0, "hard": 0.0, "major": 0.0}
n_unpriced = 0
for a in pools:
    for b in bals.get(a, []):
        v, c = usd(b["denom"], float(b["amount"]))
        if v is None:
            n_unpriced += 1
        else:
            tot[c] += v

# Osmosis other-side
osmosis_other = 0.0
for p in osmo.get("gamm", []):
    for a in p.get("assets", []):
        if a["denom"] == osmo.get("arch_denom"):
            continue
        if a["denom"] == "uosmo":
            osmosis_other += float(a["amount"]) / 1e6 * OSMO
        else:
            t = (osmo.get("denom_traces") or {}).get(a["denom"], {})
            if t.get("base_denom") in ("uusdc", "uusdt", "usdc", "usdt"):
                osmosis_other += float(a["amount"]) / 1e6 * USDC

out = {
    "source_dir": os.path.abspath(D),
    "n_pool_like_contracts": len(pools),
    "pool_arch_usd": round(tot["arch"], 2),
    "pool_hard_usd": round(tot["hard"], 2),
    "pool_major_usd": round(tot["major"], 2),
    "pool_swap_extractable_nonarch_usd": round(tot["hard"] + tot["major"], 2),
    "osmosis_gamm_other_side_usd": round(osmosis_other, 2),
    "total_measured_eu_bound_usd": round(tot["hard"] + tot["major"] + osmosis_other, 2),
    "unpriced_asset_entries": n_unpriced,
    "note": "Pool-only, swap-extractable bound. Long-tail assets in these pools are not priced; "
            "DefiLlama values the Astrovault pools at ~$111k using its own price feeds.",
}
print(json.dumps(out, indent=1))
with open(os.path.join(D, "pool_extractable_bound.json"), "w") as f:
    json.dump(out, f, indent=1)
