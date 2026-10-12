#!/usr/bin/env python3
"""Extended LP-holder contract scan: for every pool with >$50 known value, find holders
with >=1% of LP supply and check whether they are contracts (flag code_id/label/admin).
Burn address and code-317 staking are known; everything else gets inspected."""
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

rows = [r for r in json.load(open("pools-valued.json")) if r["usd_known"] > 50]
print("pools >$50:", len(rows))

def holders(lp):
    accts, key = [], None
    for _ in range(20):
        q = {"all_accounts": {"limit": 100}}
        if key:
            q["all_accounts"]["start_after"] = key
        d = cwq(lp, q)
        page = d.get("accounts", [])
        accts.extend(page)
        if len(page) < 100:
            break
        key = page[-1]
    return accts

def bal(lp, a):
    try:
        return int(cwq(lp, {"balance": {"address": a}}).get("balance", 0))
    except Exception:
        return 0

def is_contract(a):
    try:
        d = get(f"/cosmwasm/wasm/v1/contract/{a}")
        ci = d.get("contract_info", {})
        return {"code_id": ci.get("code_id"), "label": ci.get("label"), "admin": ci.get("admin"), "creator": ci.get("creator")}
    except Exception:
        return None

flagged = []
for r in rows:
    lp, ts = r["lp"], r["ts"]
    if not lp or not ts:
        continue
    try:
        accts = holders(lp)
    except Exception as e:
        print("holders err", lp, e); continue
    with ThreadPoolExecutor(max_workers=8) as ex:
        bals = list(ex.map(lambda a: bal(lp, a), accts))
    cands = [(a, b) for a, b in zip(accts, bals) if b / ts >= 0.01 and a != BURN]
    if not cands:
        continue
    with ThreadPoolExecutor(max_workers=8) as ex:
        info = list(ex.map(is_contract, [a for a, _ in cands]))
    for (a, b), ci in zip(cands, info):
        if ci:
            flagged.append({"pool": r["pair"], "pool_usd": round(r["usd_known"], 2), "lp": lp,
                            "holder": a, "balance": b, "frac": b / ts, "contract": ci})
            print(f"CONTRACT LP HOLDER: pool={r['pair']} (${r['usd_known']:.0f}) holder={a} frac={b/ts:.3f} code={ci['code_id']} label={ci['label']!r} admin={ci['admin']!r}")
json.dump(flagged, open("lp-holder-contracts.json", "w"), indent=1)
print("flagged contracts:", len(flagged))
