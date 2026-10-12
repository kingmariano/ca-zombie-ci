#!/usr/bin/env python3
"""For each CW20 that sits opposite INJ (or other priced denom) in a pool with >$100 known value,
fetch token_info (minter/cap/supply) and contract_info (code_id/admin/creator)."""
import json, base64, urllib.request, time
from concurrent.futures import ThreadPoolExecutor

LCDS = ["https://injective-api.polkachu.com", "https://injective-rest.publicnode.com"]

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
    d = get(f"/cosmwasm/wasm/v1/contract/{contract}/smart/{b64}")
    return d.get("data", d)

rows = json.load(open("pools-valued.json"))
pairs = {p["contract_addr"]: p for p in json.load(open("pairs-live.json"))["pairs"]}

# CW20s opposite a priced side, in pools worth > $100
targets = {}
for r in rows:
    if r["usd_known"] < 100:
        continue
    for k, amt, v in zip(r["kinds"], r["amounts"], r["vals"]):
        if k.startswith("CW20:") and v is None:
            c = k.split(":", 1)[1]
            targets.setdefault(c, {"seen_in": [], "priced_usd": 0.0})
            targets[c]["seen_in"].append(r["pair"])
            targets[c]["priced_usd"] += r["usd_known"]
print("cw20 targets:", len(targets))

def info(c):
    out = {"contract": c}
    try:
        out["token_info"] = cwq(c, {"token_info": {}})
    except Exception as e:
        out["token_info_err"] = str(e)
    try:
        ci = get(f"/cosmwasm/wasm/v1/contract/{c}")
        ci = ci.get("contract_info", {})
        out["code_id"] = ci.get("code_id"); out["creator"] = ci.get("creator"); out["admin"] = ci.get("admin"); out["label"] = ci.get("label")
    except Exception as e:
        out["contract_info_err"] = str(e)
    return out

with ThreadPoolExecutor(max_workers=4) as ex:
    res = list(ex.map(info, list(targets.keys())))

merged = []
for c, r in zip(targets.keys(), res):
    r["priced_side_usd"] = round(targets[c]["priced_usd"], 2)
    r["pools"] = targets[c]["seen_in"]
    merged.append(r)
merged.sort(key=lambda x: -x["priced_side_usd"])
json.dump(merged, open("cw20-info.json", "w"), indent=1)
for r in merged[:40]:
    ti = r.get("token_info") or {}
    mint = ti.get("mint")
    print(f"{r['priced_side_usd']:>10.2f} USD-opposite | {r['contract']} | code={r.get('code_id')} admin={r.get('admin')} creator={r.get('creator')} | name={ti.get('name')} sym={ti.get('symbol')} dec={ti.get('decimals')} supply={ti.get('total_supply')} mint={mint}")
