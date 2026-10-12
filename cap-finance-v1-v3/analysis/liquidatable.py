#!/usr/bin/env python3
"""Compute v3 liquidatable positions vs current Chainlink prices."""
import json, os, subprocess, urllib.request, time

RPC = os.environ.get("ARB_RPC", "https://arb1.arbitrum.io/rpc")
TRADE = "0x9BC357bc5b312AaCD41a84F3C687F031B8786853"

def sel(sig):
    return subprocess.check_output(["cast", "sig", sig]).decode().strip()

def call(to, sig, arg=None):
    data = sel(sig)
    if arg is not None:
        data += arg.rjust(64, "0")
    payload = [{"jsonrpc": "2.0", "id": 0, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]}]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    d = json.load(urllib.request.urlopen(req, timeout=30))
    return d[0].get("result")

def feed_price(feed):
    r = call(feed, "latestRoundData()")
    b = bytes.fromhex(r[2:])
    answer = int.from_bytes(b[32:64], "big", signed=True)
    return answer / 1e8

products = {}
for pid in range(1, 11):
    r = call(TRADE, "getProduct(uint256)", hex(pid)[2:])
    if not r or len(r) < 2 + 64*12:
        continue
    b = bytes.fromhex(r[2:])
    feed = "0x" + b[12:32].hex()
    maxLev = int.from_bytes(b[32:64], "big")
    fee = int.from_bytes(b[64:96], "big")
    isActive = int.from_bytes(b[96:128], "big") == 1
    maxExp = int.from_bytes(b[128:160], "big")
    oiLong = int.from_bytes(b[160:192], "big")
    oiShort = int.from_bytes(b[192:224], "big")
    interest = int.from_bytes(b[224:256], "big")
    settleTime = int.from_bytes(b[256:288], "big")
    minDur = int.from_bytes(b[288:320], "big")
    liqThr = int.from_bytes(b[320:352], "big")
    liqBounty = int.from_bytes(b[352:384], "big")
    if maxLev == 0:
        continue
    price = feed_price(feed)
    products[pid] = {"feed": feed, "price": price, "maxLev": maxLev, "fee": fee,
                     "isActive": isActive, "liqThr": liqThr, "liqBounty": liqBounty,
                     "oiLong": oiLong, "oiShort": oiShort}
    print(f"product {pid}: feed={feed} price={price:.2f} maxLev={maxLev/1e8:.0f} fee={fee} active={isActive} liqThr={liqThr} bounty={liqBounty}")

pos = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "state", "v3-open-positions.json")))
liq = []
for p in pos:
    pr = products.get(p["productId"])
    if not pr:
        continue
    entry = p["price"] / 1e8
    lev = p["leverage"] / 1e8
    # close price used by liquidatePositions: Chainlink +/- fee
    cp = pr["price"] * (1 + pr["fee"]/1e4) if not p["isLong"] else pr["price"] * (1 - pr["fee"]/1e4)
    if p["isLong"]:
        liq_price = entry - entry * pr["liqThr"] * 1e4 / p["leverage"]
        is_liq = cp <= liq_price
    else:
        liq_price = entry + entry * pr["liqThr"] * 1e4 / p["leverage"]
        is_liq = cp >= liq_price
    p2 = dict(p)
    p2["liqPrice"] = liq_price
    p2["isLiquidatable"] = is_liq
    if is_liq:
        liq.append(p2)

print(f"\nliquidatable positions: {len(liq)} / {len(pos)}")
print("liquidatable margin total:", sum(p['margin'] for p in liq)/1e8, "ETH")
for p in sorted(liq, key=lambda x: -x['margin'])[:20]:
    print(f"   id={p['positionId']} owner={p['owner'][:12]} margin={p['margin']/1e8:.6f} entry={p['price']/1e8:.2f} liqPrice={p['liqPrice']:.2f} lev={p['leverage']/1e8:.0f} long={p['isLong']}")
json.dump([{**p} for p in liq], open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "state", "v3-liquidatable.json"), "w"), indent=1)
