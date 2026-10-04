#!/usr/bin/env python3
"""Parse GeckoTerminal raw JSON into a clean venue table (census/venues_gt.json + CSV)."""
import json, os, csv

HERE = os.path.dirname(os.path.abspath(__file__))
CENSUS = os.path.dirname(HERE)
RAW = os.path.join(CENSUS, "raw")

FW = {
 "0x9e1148bc3665a9f7c35f313d89c0432c34928aef": "fwWHYPE",
 "0x0c47cbbede5d8c6f9614cf770c26c3315205c397": "fwUETH",
 "0xd2646b9b02859416d8cbc759f85f0676f6e19974": "fwUSDC",
 "0x7576dd9a2775bfd789616d9ea7a2af21d06782d0": "fwUSDT0",
 "0x09d21e89ef332347eb3e1e496f1265a600e364c1": "fwUSDH",
}

def load(f):
    p = os.path.join(RAW, f)
    if not os.path.exists(p): return None
    try: return json.load(open(p))
    except Exception: return None

pools = {}

def add_pool(it):
    a = it.get("attributes", {})
    pid = it.get("id", "")
    addr = (a.get("address") or "").lower()
    if not addr: return
    rel = it.get("relationships", {})
    def rid(k):
        d = (rel.get(k) or {}).get("data")
        if isinstance(d, dict): return d.get("id")
        if isinstance(d, list): return [x.get("id") for x in d]
        return None
    p = pools.setdefault(addr, {"pool_id": pid, "address": addr, "name": a.get("name")})
    for k in ("base_token_price_usd", "quote_token_price_usd", "base_token_price_quote_token",
              "quote_token_price_base_token", "reserve_in_usd", "fdv_usd", "market_cap_usd",
              "pool_created_at"):
        if a.get(k) is not None: p[k] = a.get(k)
    vol = a.get("volume_usd")
    if isinstance(vol, dict): p["volume_usd"] = vol
    txns = a.get("transactions")
    if isinstance(txns, dict): p["transactions"] = txns
    p.setdefault("dex_id", rid("dex"))
    p.setdefault("base_token_id", rid("base_token"))
    p.setdefault("quote_token_id", rid("quote_token"))

# per-token pool lists
for name in ["fwWHYPE", "fwUETH", "fwUSDC", "fwUSDT0", "fwUSDH"]:
    for page in ("p1", "p2"):
        d = load(f"gt_{name}_pools_{page}.json")
        if not d or "data" not in d: continue
        for it in d["data"]: add_pool(it)

# pool detail endpoints
for f in ["gt_pool_p1_fwUETH_fwWHYPE.json", "gt_pool_p2_fwUSDH_fwUSDC.json", "gt_pool_p3_fwUSDH_fwUSDT0.json",
          "gt_pool_p4_fwUSDT0_fwUSDC.json", "gt_pool_p5_fwUSDT0_fwWHYPE.json"]:
    d = load(f)
    if d and isinstance(d.get("data"), dict): add_pool(d["data"])

# searches
for name in ["fwWHYPE", "fwUETH", "fwUSDC", "fwUSDT0", "fwUSDH"]:
    d = load(f"gt_search_{name}.json")
    if d and isinstance(d.get("data"), list):
        for it in d["data"]: add_pool(it)

out = []
for addr, p in sorted(pools.items()):
    b = p.get("base_token_id") or ""; q = p.get("quote_token_id") or ""
    baddr = b.split("_")[-1].lower() if b else ""
    qaddr = q.split("_")[-1].lower() if q else ""
    p["base_symbol"] = FW.get(baddr, baddr)
    p["quote_symbol"] = FW.get(qaddr, qaddr)
    out.append(p)

json.dump(out, open(os.path.join(CENSUS, "venues_gt.json"), "w"), indent=1)
with open(os.path.join(CENSUS, "venues_gt.csv"), "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(["pool", "name", "dex_id", "base", "quote", "base_price_usd", "quote_price_usd", "reserve_usd", "vol24_usd", "created"])
    for p in out:
        v = p.get("volume_usd") or {}
        w.writerow([p["address"], p.get("name"), p.get("dex_id"), p.get("base_symbol"), p.get("quote_symbol"),
                    p.get("base_token_price_usd"), p.get("quote_token_price_usd"), p.get("reserve_in_usd"),
                    v.get("h24") if isinstance(v, dict) else None, p.get("pool_created_at")])
print(json.dumps(out, indent=1))
print("pools:", len(out))
