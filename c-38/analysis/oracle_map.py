#!/usr/bin/env python3
"""Read TectonicOracleAdapter per-market feeds + prices; fetch real prices from DefiLlama."""
import json
import urllib.request
import urllib.parse

RPC = "https://cronos-evm-rpc.publicnode.com"
ADAPTER = "0xD360D8cABc1b2e56eCf348BFF00D2Bd9F658754A"
UNITROLLER = "0xb3831584acb95ED9cCb0C11f677B5AD01DeaeEc0"

state = json.load(open("state-97651394.json"))
markets = state["markets"]


def rpc(method, params):
    payload = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    req = urllib.request.Request(RPC, data=payload, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        out = json.loads(r.read())
    if "result" in out:
        return out["result"]
    return {"__error__": out.get("error")}


def enc_addr(a):
    return a.lower().replace("0x", "").rjust(64, "0")


def dec_addr(h):
    if isinstance(h, dict) or not h or len(h) < 42:
        return h
    return "0x" + h[-40:]


def dec_uint(h):
    if isinstance(h, dict):
        return h
    if not h or h == "0x":
        return None
    return int(h, 16)


def batch(calls, block="latest"):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i + 10]
        payload = [{"jsonrpc": "2.0", "method": "eth_call", "params": [{"to": t, "data": d}, block], "id": j} for j, (t, d) in enumerate(chunk)]
        req = urllib.request.Request(RPC, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            got = json.loads(r.read())
        by_id = {x.get("id"): x for x in got}
        for j in range(len(chunk)):
            it = by_id.get(j, {})
            out.append(it["result"] if "result" in it else {"__error__": it.get("error")})
    return out


print("=== adapter owner / isPriceOracle ===")
res = batch([(ADAPTER, "0x8da5cb5b"), (ADAPTER, "0x66331bba")])
print("owner:", dec_addr(res[0]), "isPriceOracle:", dec_uint(res[1]))

print("\n=== per-market oracle mapping ===")
calls = []
for m in markets:
    calls.append((ADAPTER, "0x3a037039" + enc_addr(m)))  # tTokenToOracle(address)
res = batch(calls)
mapping = {}
for m, r in zip(markets, res):
    feed = dec_addr(r)
    mapping[m] = feed
    print(f"{markets[m]['symbol']:10s} {m} -> {feed}")

print("\n=== feed latestRoundData + decimals ===")
feeds = sorted(set(v for v in mapping.values() if isinstance(v, str)))
calls = []
for f in feeds:
    calls.append((f, "0xfeaf968c"))  # latestRoundData()
    calls.append((f, "0x313ce567"))  # decimals()
res = batch(calls)
feed_info = {}
for i, f in enumerate(feeds):
    lrd = res[2 * i]
    dec = res[2 * i + 1]
    info = {"raw": lrd, "decimals": dec_uint(dec)}
    if isinstance(lrd, str) and lrd.startswith("0x") and len(lrd) >= 2 + 64 * 5:
        b = bytes.fromhex(lrd[2:])
        info.update({
            "roundId": int.from_bytes(b[0:32], "big"),
            "answer": int.from_bytes(b[32:64], "big", signed=True),
            "startedAt": int.from_bytes(b[64:96], "big"),
            "updatedAt": int.from_bytes(b[96:128], "big"),
            "answeredInRound": int.from_bytes(b[128:160], "big"),
        })
    feed_info[f] = info
    print(f, json.dumps(info))

json.dump({"mapping": mapping, "feeds": feed_info}, open("oracle_map.json", "w"), indent=1)

# real prices from DefiLlama
underlyings = {}
for m, d in markets.items():
    u = d.get("underlying")
    if isinstance(u, str) and u:
        underlyings[u] = d["symbol"]
underlyings["coingecko:crypto-com-chain"] = "tCRO"

ids = list(underlyings.keys())
url = "https://coins.llama.fi/prices/current/" + ",".join(ids)
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=30) as r:
    prices = json.loads(r.read())
print("\n=== DefiLlama prices ===")
real = {}
for k, v in prices.get("coins", {}).items():
    real[k] = v.get("price")
    print(f"{underlyings.get(k, k):12s} {k} -> ${v.get('price')} (conf {v.get('confidence')})")
json.dump(real, open("real_prices.json", "w"), indent=1)
