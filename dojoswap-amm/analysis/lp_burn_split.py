#!/usr/bin/env python3
"""Classify pool value by LP custody: burned (burn contract) vs live LP holders.
burn address = inj1wu0cs0zl38pfss54df6t7hq82k3lgmcdex2uwn (contract 'Dojoswap Burn Address', code 292)."""
import json, base64, urllib.request
from concurrent.futures import ThreadPoolExecutor

LCDS = ["https://injective-api.polkachu.com", "https://injective-rest.publicnode.com"]
BURN = "inj1wu0cs0zl38pfss54df6t7hq82k3lgmcdex2uwn"

def get(path, timeout=30):
    last = None
    for lcd in LCDS:
        try:
            req = urllib.request.Request(lcd + path, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode())
        except Exception as e:
            last = e
    raise RuntimeError(str(last))

def cwq(contract, query):
    b64 = base64.b64encode(json.dumps(query, separators=(",", ":")).encode()).decode()
    return get(f"/cosmwasm/wasm/v1/contract/{contract}/smart/{b64}").get("data", {})

rows = [r for r in json.load(open("pools-valued.json")) if r["usd_known"] > 0]
print("valued pools:", len(rows))

def burn_bal(lp):
    try:
        return int(cwq(lp, {"balance": {"address": BURN}}).get("balance", 0))
    except Exception:
        return None

with ThreadPoolExecutor(max_workers=5) as ex:
    bals = list(ex.map(lambda r: burn_bal(r["lp"]), rows))

burn_usd = live_usd = 0.0
burn_pools, live_pools = [], []
for r, b in zip(rows, bals):
    ts = r["ts"] or 1
    frac = (b or 0) / ts if ts else 0
    if frac >= 0.95:
        burn_usd += r["usd_known"]; burn_pools.append((r["pair"], round(r["usd_known"], 2), frac))
    else:
        live_usd += r["usd_known"]; live_pools.append((r["pair"], round(r["usd_known"], 2), frac, r["usd_known"]))
print(f"value in pools with >=95% LP burned: ${burn_usd:,.2f} across {len(burn_pools)} pools")
print(f"value in pools with live LP:         ${live_usd:,.2f} across {len(live_pools)} pools")
print("\ntop burned-LP pools:")
for p in sorted(burn_pools, key=lambda x: -x[1])[:15]:
    print(f"  ${p[1]:>10,.2f} burn_frac={p[2]:.4f} {p[0]}")
print("\ntop live-LP pools:")
for p in sorted(live_pools, key=lambda x: -x[1])[:15]:
    print(f"  ${p[1]:>10,.2f} burn_frac={p[2]:.4f} {p[0]}")
json.dump({"burn_usd": burn_usd, "live_usd": live_usd,
           "burn_pools": burn_pools, "live_pools": live_pools}, open("lp-burn-split.json", "w"), indent=1)
