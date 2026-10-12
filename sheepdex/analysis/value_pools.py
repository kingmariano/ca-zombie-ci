#!/usr/bin/env python3
"""Read token symbols/decimals for all tokens in pools, then price via DefiLlama.
Writes tokens.json and pool-values.json."""
import json, os, urllib.request, time

RPC = os.environ["BSC_RPC"]
d = json.load(open("pools-state.json"))
pools = d["pools"]
tokens = sorted({p["token0"] for p in pools} | {p["token1"] for p in pools})

def batch(calls):
    payload = [{"jsonrpc": "2.0", "id": i, "method": "eth_call",
                "params": [{"to": to, "data": data}, "latest"]} for i, (to, data) in enumerate(calls)]
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    for a in range(4):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                resp = json.load(r)
            break
        except Exception as e:
            print("retry", e); time.sleep(2)
    out = {}
    for item in resp:
        out[item["id"]] = item.get("result") if "error" not in item else None
    return [out[i] for i in range(len(calls))]

def dec_str(x):
    if not isinstance(x, str) or not x.startswith("0x"): return None
    b = bytes.fromhex(x[2:])
    if len(b) < 64: return None
    off = int.from_bytes(b[0:32], "big")
    ln = int.from_bytes(b[off:off+32], "big")
    return b[off+32:off+32+ln].decode("utf8", "replace")

calls, meta = [], []
for t in tokens:
    calls += [(t, "0x95d89b41"), (t, "0x313ce567")]  # symbol(), decimals()
    meta += [("symbol", t), ("decimals", t)]
res = batch(calls)
info = {}
for (kind, t), r in zip(meta, res):
    info.setdefault(t, {})[kind] = dec_str(r) if kind == "symbol" else (int(r, 16) if isinstance(r, str) else None)
print(json.dumps({t: info[t] for t in tokens}, indent=1))

# prices from DefiLlama
prices = {}
for i in range(0, len(tokens), 30):
    chunk = tokens[i:i+30]
    ids = ",".join("bsc:" + t for t in chunk)
    url = "https://coins.llama.fi/prices/current/" + ids
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            pj = json.load(r)
        for k, v in pj.get("coins", {}).items():
            prices[k.split(":")[1].lower()] = {"price": v.get("price"), "symbol": v.get("symbol"), "decimals": v.get("decimals"), "confidence": v.get("confidence")}
    except Exception as e:
        print("price err", e)
    time.sleep(0.3)

out = []
tot = 0.0
for p in pools:
    t0, t1 = p["token0"], p["token1"]
    d0 = info.get(t0, {}).get("decimals") or 18
    d1 = info.get(t1, {}).get("decimals") or 18
    p0 = prices.get(t0, {}).get("price")
    p1 = prices.get(t1, {}).get("price")
    a0 = (p["bal0"] or 0) / 10**d0
    a1 = (p["bal1"] or 0) / 10**d1
    v0 = a0 * p0 if p0 else None
    v1 = a1 * p1 if p1 else None
    v = (v0 or 0) + (v1 or 0)
    tot += v
    out.append({**p, "sym0": info.get(t0, {}).get("symbol"), "sym1": info.get(t1, {}).get("symbol"),
                "dec0": d0, "dec1": d1, "amt0": a0, "amt1": a1, "price0": p0, "price1": p1,
                "usd0": v0, "usd1": v1, "usd": v})
json.dump({"latest_block": d["latest_block"], "prices": prices, "tokens": info, "pools": out},
          open("pool-values.json", "w"), indent=1)
out.sort(key=lambda x: -(x["usd"] or 0))
print(f"\nTOTAL priced pool balances: ${tot:,.0f}")
print("TOP 25 pools by USD:")
for p in out[:25]:
    print(f'{p["pool"]} {p["sym0"]}/{p["sym1"]} fee={p["fee"]} liq={p["liquidity"]} usd={p["usd"]:,.0f} '
          f'({p["amt0"]:.4g} {p["sym0"]} = {p["usd0"] and round(p["usd0"])}, {p["amt1"]:.4g} {p["sym1"]} = {p["usd1"] and round(p["usd1"])})')
