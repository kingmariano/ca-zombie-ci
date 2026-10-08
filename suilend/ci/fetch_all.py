#!/usr/bin/env python3
"""C2-11 Suilend heavy-pull job: version chain, module hashes, market state, liquidate-event differential.
Read-only. Outputs JSON/CSV into ci-out/."""
import json, base64, hashlib, sys, os, time, urllib.request

ENDPOINTS = ["https://sui.publicnode.com", "https://mainnet.sui.rpcpool.com", "https://sui-rpc.publicnode.com"]
GRAPHQL = "https://graphql.mainnet.sui.io/graphql"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ci-out")
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)
MARKET = "0x84030d26d85eaa7035084a057f2f11f701b7e2e4eda87551becbc7c97505ece1"
ORIG = "0xf95b06141ed4a174f239417323bde3f209b972f5930d8521ea38a52aff3a6ddf"

_rpc_rot = [0]

def rpc(method, params):
    last = None
    for attempt in range(6):
        _rpc_rot[0] += 1
        order = ENDPOINTS[_rpc_rot[0] % len(ENDPOINTS):] + ENDPOINTS[:_rpc_rot[0] % len(ENDPOINTS)]
        for ep in order:
            try:
                req = urllib.request.Request(ep, data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                                             headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"})
                with urllib.request.urlopen(req, timeout=45) as r:
                    j = json.loads(r.read())
                if "error" in j:
                    last = j
                    continue
                time.sleep(0.25)
                return j.get("result")
            except Exception as e:
                last = str(e)
        time.sleep(8 + attempt * 10)
    raise RuntimeError(f"{method} failed: {last}")

def gql(query):
    req = urllib.request.Request(GRAPHQL, data=json.dumps({"query": query}).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"})
    with urllib.request.urlopen(req, timeout=60) as r:
        j = json.loads(r.read())
    if "errors" in j:
        raise RuntimeError(str(j["errors"])[:400])
    return j["data"]

def log(*a):
    print(*a, flush=True)

# ---------- 1. version chain ----------
log("[1] package version chain")
q = f'query {{ object(address: "{ORIG}") {{ asMovePackage {{ address version packageVersionsAfter(first: 50) {{ nodes {{ address version }} }} }} }} }}'
vers = gql(q)["object"]["asMovePackage"]["packageVersionsAfter"]["nodes"]
version_map = {str(n["version"]): n["address"] for n in vers}
version_map["1"] = ORIG
json.dump(version_map, open(os.path.join(OUT, "version_chain.json"), "w"), indent=1)
log(f"    {len(version_map)} versions, latest v{max(int(v) for v in version_map)}")

# ---------- 2. module bytecode hashes for all versions ----------
log("[2] module bytecode hashes (all versions)")
timeline = {}
obj_versions = {}
SAVE_MODULES = {"10", "18", "20", "22", "23", "24", "25"}
for v in sorted(version_map, key=int):
    time.sleep(0.4)
    pid = version_map[v]
    pkg = rpc("sui_getObject", [pid, {"showBcs": True}])
    bcs = pkg["data"]["bcs"]
    obj_versions[v] = {"package_id": pid, "object_version": pkg["data"].get("version")}
    for m, b64 in bcs.get("moduleMap", {}).items():
        h = hashlib.sha256(base64.b64decode(b64)).hexdigest()[:16]
        timeline.setdefault(m, []).append((int(v), h))
        if v in SAVE_MODULES:
            d = os.path.join(OUT, "modules", f"v{v}")
            os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, m + ".mv"), "wb") as fh:
                fh.write(base64.b64decode(b64))
out = {}
for m, seq in timeline.items():
    changes, prev = [], None
    for v, h in sorted(seq):
        if h != prev:
            changes.append({"v": v, "hash": h})
            prev = h
    out[m] = changes
json.dump({"module_hash_timeline": out, "versions": obj_versions}, open(os.path.join(OUT, "module_hash_timeline.json"), "w"), indent=1)
log("    saved module_hash_timeline.json")

# ---------- 3. main market state + reserves ----------
log("[3] main market state")
mkt = rpc("sui_getObject", [MARKET, {"showContent": True}])
f = mkt["data"]["content"]["fields"]
json.dump(mkt, open(os.path.join(OUT, "market_raw.json"), "w"))
reserves = []
for r in f["reserves"]:
    time.sleep(0.3)
    x = r["fields"]; cfg = x["config"]["fields"]["element"]["fields"]
    dec = int(x["mint_decimals"]); price = int(x["price"]["fields"]["value"]) / 1e18
    avail = int(x["available_amount"]) / 10**dec
    borr = int(x["borrowed_amount"]["fields"]["value"]) / 1e18 / 10**dec
    reserves.append({
        "idx": int(x["array_index"]), "coin": x["coin_type"]["fields"]["name"],
        "price_usd": price, "decimals": dec, "available": avail, "available_usd": avail * price,
        "borrowed": borr, "borrowed_usd": borr * price,
        "ctoken_supply": int(x["ctoken_supply"]), "price_fresh_s": int(time.time()) - int(x["price_last_update_timestamp_s"]),
        "open_ltv": int(cfg["open_ltv_pct"]), "close_ltv": int(cfg["close_ltv_pct"]),
        "liq_bonus_bps": int(cfg["liquidation_bonus_bps"]), "proto_fee_bps": int(cfg["protocol_liquidation_fee_bps"]),
        "borrow_weight_bps": int(cfg["borrow_weight_bps"]), "isolated": bool(cfg["isolated"]),
        "config_bag_size": int(cfg["additional_fields"]["fields"].get("size", 0)),
    })
json.dump({"market_version": f["version"], "obligations": f["obligations"]["fields"]["size"],
           "bad_debt_usd": f["bad_debt_usd"]["fields"]["value"], "reserves": reserves},
          open(os.path.join(OUT, "main_market_reserves.json"), "w"), indent=1)
tot_a = sum(r["available_usd"] for r in reserves); tot_b = sum(r["borrowed_usd"] for r in reserves)
log(f"    reserves={len(reserves)} available_usd={tot_a:,.0f} borrowed_usd={tot_b:,.0f}")

# ---------- 4. dynamic fields: market + all reserves (pause/price-guard presence) ----------
log("[4] dynamic fields (pause / price-guard detection)")
def all_df(obj):
    out2, cursor = [], None
    for _ in range(30):
        r = rpc("suix_getDynamicFields", [obj, cursor, 50])
        out2 += r["data"]
        if not r.get("hasNextPage"):
            break
        cursor = r.get("nextCursor")
    return out2
dfout = {"market": [], "reserves": {}}
for e in all_df(MARKET):
    dfout["market"].append({"name": e.get("name", {}), "objectType": e.get("objectType")})
for r in f["reserves"]:
    time.sleep(0.3)
    x = r["fields"]; uid = x["id"]["id"]; coin = x["coin_type"]["fields"]["name"].split("::")[-1]
    df = all_df(uid)
    dfout["reserves"][f"{x['array_index']}:{coin}"] = [{"name": e.get("name", {}), "objectType": e.get("objectType")} for e in df]
json.dump(dfout, open(os.path.join(OUT, "dynamic_fields.json"), "w"), indent=1)
guard = [k for k, v in dfout["reserves"].items() if any("PriceGuard" in str(e) or "Pause" in str(e) for e in v)]
log(f"    reserves with pause/price-guard dynamic fields: {guard if guard else 'NONE'}")

# ---------- 5. all lending markets ----------
log("[5] lending markets registry")
reg = gql('query { objects(first: 5, filter: { type: "%s::lending_market_registry::Registry" }) { nodes { address asMoveObject { contents { json } } } } }' % ORIG)
regnode = reg["objects"]["nodes"][0]
regaddr = regnode["address"]
tbl = regnode["asMoveObject"]["contents"]["json"]["lending_markets"]["id"]
fields, cursor = [], None
for _ in range(10):
    r = rpc("suix_getDynamicFields", [tbl, cursor, 50])
    fields += r["data"]
    if not r.get("hasNextPage"):
        break
    cursor = r.get("nextCursor")
markets = []
for e in fields:
    pool = e["name"]["value"]["name"]; fid = e["objectId"]
    o = rpc("sui_getObject", [fid, {"showContent": True}])
    mid = o["data"]["content"]["fields"].get("value") if isinstance(o, dict) and o.get("data", {}).get("content") else None
    m = rpc("sui_getObject", [mid, {"showContent": True}]) if mid else None
    info = {"pool": pool, "market": mid}
    if m and m.get("data", {}).get("content"):
        cf = m["data"]["content"]["fields"]
        info.update({"version": cf.get("version"), "reserves": len(cf.get("reserves", [])),
                     "obligations": cf.get("obligations", {}).get("fields", {}).get("size")})
    markets.append(info)
json.dump({"registry": regaddr, "markets": markets}, open(os.path.join(OUT, "all_markets.json"), "w"), indent=1)
log(f"    {len(markets)} markets registered")

# ---------- 6. liquidate events (last ~400) + differential ----------
log("[6] liquidate events + old-package bonus differential")
TYPE = f"{ORIG}::lending_market::LiquidateEvent"
def evpage(before=None):
    qq = 'query { events(last: 50, %s filter: { type: "%s" }) { nodes { timestamp contents { json } } pageInfo { hasPreviousPage startCursor } } }' % (
        (f'before: "{before}",' if before else ""), TYPE)
    return gql(qq)["events"]
p = evpage(); events = p["nodes"]; cursor = p["pageInfo"]["startCursor"]
while p["pageInfo"]["hasPreviousPage"] and len(events) < 400:
    p = evpage(cursor); events = p["nodes"] + events; cursor = p["pageInfo"]["startCursor"]
json.dump(events, open(os.path.join(OUT, "liquidate_events.json"), "w"), indent=1)
res_by_id = {r["fields"]["id"]["id"]: r["fields"] for r in f["reserves"]}
tot_repay = tot_extra = 0.0; n_capped = 0; rows = []
for e in events:
    pj = e["contents"]["json"]
    rr = res_by_id.get(pj["repay_reserve_id"]); wr = res_by_id.get(pj["withdraw_reserve_id"])
    if not rr or not wr:
        continue
    rdec = int(rr["mint_decimals"]); rprice = int(rr["price"]["fields"]["value"]) / 1e18
    wdec = int(wr["mint_decimals"]); wprice = int(wr["price"]["fields"]["value"]) / 1e18
    repay = int(pj["repay_amount"]) / 10**rdec * rprice
    wd = int(pj["withdraw_amount"]) / 10**wdec * wprice
    if repay <= 0:
        continue
    conf = (int(wr["config"]["fields"]["element"]["fields"]["liquidation_bonus_bps"]) +
            int(wr["config"]["fields"]["element"]["fields"]["protocol_liquidation_fee_bps"])) / 10000
    ratio = wd / repay
    extra = repay * (conf - (ratio - 1)) if ratio - 1 < conf - 0.0005 else 0.0
    if extra > 0:
        n_capped += 1
    tot_repay += repay; tot_extra += extra
    rows.append({"ts": e["timestamp"], "repay_usd": round(repay, 4), "withdraw_usd": round(wd, 4),
                 "ratio": round(ratio, 6), "configured_bonus": round(conf, 6), "extra_v10_v18_usd": round(extra, 4)})
json.dump({"n_events": len(events), "n_capped": n_capped, "total_repay_usd": round(tot_repay, 2),
           "total_extra_usd": round(tot_extra, 2), "rows": rows},
          open(os.path.join(OUT, "liquidation_differential.json"), "w"), indent=1)
if events:
    span_days = (time.time() - time.mktime(time.strptime(events[0]["timestamp"][:19], "%Y-%m-%dT%H:%M:%S"))) / 86400
    log(f"    events={len(events)} capped={n_capped} repay=${tot_repay:,.0f} extra≈${tot_extra:,.2f} over {span_days:.1f}d -> ${tot_extra/max(span_days,1e-9):,.2f}/day")

log("DONE")
