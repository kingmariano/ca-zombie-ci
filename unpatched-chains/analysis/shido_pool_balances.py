#!/usr/bin/env python3
"""Read V3-style pool balances (ERC-20 balanceOf) + price via DefiLlama. Read-only."""
import json, urllib.request
from concurrent.futures import ThreadPoolExecutor

RPC = "https://evm.shidoscan.net"
UA = {"User-Agent": "zombie-research/1.0", "Content-Type": "application/json"}

def rpc_batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers=UA)
    return json.loads(urllib.request.urlopen(req, timeout=30).read())

def http(url):
    req = urllib.request.Request(url, headers={"User-Agent": "zombie-research/1.0"})
    return json.loads(urllib.request.urlopen(req, timeout=30).read())

raw = json.load(open("shido_pair_scan_raw.json"))
prev = json.load(open("shido_pair_reserves.json"))
meta = prev["meta"]
pairs = raw["pairs"]

def pad_addr(a):
    return "0x" + a[2:].rjust(64, "0")

rows = []
calls = []
order = []
for a, p in pairs.items():
    t0, t1 = p["token0"].lower(), p["token1"].lower()
    rows.append({"pair": a, "token0": t0, "token1": t1})
    calls.append(("eth_call", [{"to": t0, "data": "0x70a08231" + pad_addr(a)[2:]}, "latest"]))
    calls.append(("eth_call", [{"to": t1, "data": "0x70a08231" + pad_addr(a)[2:]}, "latest"]))
    calls.append(("eth_call", [{"to": a, "data": "0x1a686502"}, "latest"]))  # liquidity()
    calls.append(("eth_call", [{"to": a, "data": "0xddca3f43"}, "latest"]))  # fee()

res = rpc_batch(calls)
for i, r in enumerate(rows):
    b0 = res[4*i].get("result"); b1 = res[4*i+1].get("result")
    liq = res[4*i+2].get("result"); fee = res[4*i+3].get("result")
    d0 = meta[r["token0"]]["decimals"]; d1 = meta[r["token1"]]["decimals"]
    r["bal0"] = int(b0, 16) if b0 and b0 != '0x' else 0
    r["bal1"] = int(b1, 16) if b1 and b1 != '0x' else 0
    r["human0"] = r["bal0"] / 10**d0 if d0 else None
    r["human1"] = r["bal1"] / 10**d1 if d1 else None
    r["liquidity"] = int(liq, 16) if liq and liq != '0x' else None
    r["fee"] = int(fee, 16) if fee and fee != '0x' else None
    r["symbol0"] = meta[r["token0"]]["symbol"]; r["symbol1"] = meta[r["token1"]]["symbol"]

# prices via defillama coins
tokens = sorted({r["token0"] for r in rows} | {r["token1"] for r in rows})
price_ids = ",".join(f"shido:{t}" for t in tokens)
pr = http(f"https://coins.llama.fi/prices/current/{price_ids}")
prices = {k.split(':')[1].lower(): v.get('price') for k, v in pr.get('coins', {}).items()}

total_non_shido = 0.0
print(f"{'pair':46} {'token0':>16} {'token1':>16}  {'usd0':>12} {'usd1':>12}  fee")
for r in rows:
    p0 = prices.get(r["token0"]); p1 = prices.get(r["token1"])
    u0 = (r["human0"] or 0) * (p0 or 0); u1 = (r["human1"] or 0) * (p1 or 0)
    r["usd0"], r["usd1"] = u0, u1
    print(f"{r['pair']:46} {r['symbol0']:>16} {r['symbol1']:>16}  {u0:12,.2f} {u1:12,.2f}  {r['fee']}")
    # non-SHIDO side = the side that isn't WSHIDO/SHIDO
    if r["token0"] == "0x8cbaffd9b658997e7bf87e98febf6ea6917166f7":
        total_non_shido += u1
    elif r["token1"] == "0x8cbaffd9b658997e7bf87e98febf6ea6917166f7":
        total_non_shido += u0

print(f"\nSUMMED non-WSHIDO side of WSHIDO pairs: ${total_non_shido:,.2f}")
json.dump({"rows": rows, "prices": prices, "total_non_wshido_usd": total_non_shido},
          open("shido_pool_balances.json", "w"), indent=1)
