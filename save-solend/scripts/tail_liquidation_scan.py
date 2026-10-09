#!/usr/bin/env python3
"""Scan all funded markets for currently-liquidatable obligations (correct deployed layout).
Headers via getProgramAccounts dataSlice 204; compositions for liquidatable; evaluate with sim prices."""
import json, base64, time, urllib.request, collections

AN = "/home/heisenberg/CA/save-solend/analysis"
RPCS = ["https://api.mainnet-beta.solana.com", "https://solana-rpc.publicnode.com"]
ri = [0]
def rpc(method, params, retries=8, timeout=300):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    delay = 1.0
    for t in range(retries):
        url = RPCS[ri[0] % 2]
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"})
            out = json.load(urllib.request.urlopen(req, timeout=timeout))
            if "error" in out: raise RuntimeError(str(out["error"])[:150])
            return out["result"]
        except Exception:
            if t == retries - 1: raise
            ri[0] += 1; time.sleep(delay); delay *= 1.6

def u(b, o, n): return int.from_bytes(b[o:o+n], "little")
ALPH = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
def b58(b):
    n = int.from_bytes(b, "big"); s = ""
    while n: n, r = divmod(n, 58); s = ALPH[r] + s
    return "1" * (len(b) - len(b.lstrip(b"\0"))) + (s or "")

st = json.load(open("/tmp/opencode/solend_state_v2.json"))
px = json.load(open(f"{AN}/prices.json"))["prices"]
sim = {s["reserve"]: s for s in json.load(open("/tmp/opencode/simsolend/out_all.json")) if s.get("reserve")}
resrows = {r["reserve"]: r for r in json.load(open(f"{AN}/reserves.json"))}
rawres = st["reservesRaw"]
funded = json.load(open(f"{AN}/funded-markets.json"))

def wad(x): return x / 1e18
def sp(rk):
    s = sim.get(rk)
    if not s or not s.get("ok") or not s.get("post"): return None
    return (int(s["post"]["marketPriceWads"]) / 1e18, int(s["post"]["smoothedPriceWads"]) / 1e18)

RD = {}
for rk, r in rawres.items():
    if "err" in r: continue
    dec = r["mintDecimals"]; p = sp(rk)
    cm, cs = p if p else (wad(r["marketPrice"]), wad(r["smoothedMarketPrice"]))
    lo, hi = min(cm, cs), max(cm, cs)
    if r["extraMarketPrice"] is not None:
        lo = min(lo, wad(r["extraMarketPrice"])); hi = max(hi, wad(r["extraMarketPrice"]))
    tl = r["availableAmount"] + wad(r["borrowedAmountWads"]) - wad(r["config"]["accumulatedProtocolFeesWads"])
    csup = r["collateralMintTotalSupply"] / 10**dec
    RD[rk] = {"dec": dec, "cm": cm, "lo": lo, "hi": hi, "cur_rate": wad(r["cumulativeBorrowRateWads"]),
              "exch": (tl / 10**dec) / csup if csup > 0 else 1.0,
              "real": (px.get(r["mint"]) or {}).get("usd"), "bw": 1 + r["config"]["addedBorrowWeightBps"] / 10000,
              "ltv": r["config"]["loanToValueRatio"] / 100, "thr": r["config"]["liquidationThreshold"] / 100,
              "mthr": r["config"]["maxLiquidationThreshold"] / 100, "bonus": r["config"]["liquidationBonus"] / 100,
              "mbonus": r["config"]["maxLiquidationBonus"] / 100, "plf": r["config"]["protocolLiquidationFee"] / 1000,
              "sym": (st["cfgRows"].get(rk, {}).get("liquidityToken") or {}).get("symbol"), "ref": p is not None}

def decode_obl(hx):
    b = bytes.fromhex(hx); o = {"d": [], "b": []}; off = 204
    for _ in range(b[202]):
        o["d"].append({"r": b58(b[off:off+32]), "a": int.from_bytes(b[off+32:off+40], "little")}); off += 88
    for _ in range(b[203]):
        o["b"].append({"r": b58(b[off:off+32]), "cum": int.from_bytes(b[off+32:off+48], "little"),
                       "a": int.from_bytes(b[off+48:off+64], "little")}); off += 112
    return o

summary = []
allres = []
for f in funded:
    m = f["market"]
    try:
        raw = rpc("getProgramAccounts", ["So1endDq2YkqhipRh3WViPa8hdiSpxWy6z3Z6tMCpAo",
            {"encoding": "base64", "filters": [{"dataSize": 1300}, {"memcmp": {"offset": 10, "bytes": m}}],
             "dataSlice": {"offset": 0, "length": 204}}])
    except Exception as e:
        summary.append({"market": m, "name": f["name"], "error": str(e)[:120]}); print("ERR", f["name"], str(e)[:80]); continue
    liq = []
    for it in raw:
        b = base64.b64decode(it["account"]["data"][0])
        borrowed = u(b, 90, 16) / 1e18; unhealthy = u(b, 122, 16) / 1e18
        if b[203] > 0 and unhealthy > 0 and borrowed >= unhealthy:
            liq.append(it["pubkey"])
    summary.append({"market": m, "name": f["name"], "nObl": len(raw), "storedLiq": len(liq)})
    print(f"{str(f['name'])[:24]:24} n={len(raw):>7} storedLiq={len(liq):>5}")
    if not liq: continue
    # fetch compositions
    comp = {}
    for k in range(0, len(liq), 50):
        batch = liq[k:k+50]
        res = rpc("getMultipleAccounts", [batch, {"encoding": "base64", "commitment": "confirmed"}])
        for a, acc in zip(batch, res["value"]):
            if acc is not None: comp[a] = base64.b64decode(acc["data"][0]).hex()
        time.sleep(0.2)
    for obl, hx in comp.items():
        try: c = decode_obl(hx)
        except Exception: continue
        if any(x["r"] not in RD for x in c["d"] + c["b"]): continue
        dep_u = dep_lo = 0.0
        for d in c["d"]:
            rd = RD[d["r"]]; tok = d["a"] / 10**rd["dec"] * rd["exch"]
            dep_u += tok * rd["cm"] * rd["thr"]; dep_lo += tok * rd["lo"] * rd["ltv"]
        bor_v = 0.0
        for br in c["b"]:
            rd = RD[br["r"]]; debt = wad(br["a"]) * (rd["cur_rate"] / wad(br["cum"])) / 10**rd["dec"]
            bor_v += debt * rd["cm"] * rd["bw"]
        if not (dep_u > 0 and bor_v >= dep_u): continue
        allres.append({"market": m, "name": f["name"], "obligation": obl, "borrowedNow": bor_v, "unhealthyNow": dep_u,
                       "ratio": bor_v / dep_u, "allRefreshable": all(RD[x["r"]]["ref"] for x in c["d"] + c["b"]),
                       "composition": c})

json.dump({"summary": summary, "liquidatableNow": allres}, open(f"{AN}/tail-liquidation-now.json", "w"), indent=1)
print("=== currently liquidatable (all markets):", len(allres))
tot = collections.Counter()
for r in allres:
    tot[r["name"]] += r["borrowedNow"]
for n, v in tot.most_common(20):
    print(f"  {str(n)[:24]:24} ${v:,.0f}")
print("refreshable among them:", sum(1 for r in allres if r["allRefreshable"]))
