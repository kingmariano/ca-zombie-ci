#!/usr/bin/env python3
"""Taiga Acala - archive forensics v2: raw-hex comparison of Pools[0] + Homa rate history.
Read-only, public RPC archive state."""
import json, urllib.request, time

URL = "https://acala-rpc-0.aca-api.network"
POOLS0 = "0xdf6d686ceec038b9a329ab96ac9e854b4c72016d74b63ae83d79b02efdb5528e11d2df4e979aa105cf552e9544ebd2b500000000"
LDOT_ISSUANCE = "0x99971b5749ac43e0235e41b0d378691857c875e4cff74148e4628f264b974c8088730a11ad01953f0003"
TSB = "0xcd3ceba33dff67841ba50ee5073a4d4564c6b8baa7ab2885e542aa179f86dd16"
TVL = "0xcd3ceba33dff67841ba50ee5073a4d4551a222dae154389eb442e1fb94f012ae"
TSNOW = "0xf0c365c3cf59d671eb72da0e7a4113c49f1f0515f462cdcf84e0f1d6045dfcbb"
TSBONDED = TSB

def rpc(method, params, retries=4):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for _ in range(retries):
        try:
            req = urllib.request.Request(URL, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (research)"})
            with urllib.request.urlopen(req, timeout=60) as r:
                j = json.loads(r.read().decode())
            if "error" in j: raise RuntimeError(j["error"])
            return j.get("result")
        except Exception as e:
            last = e; time.sleep(1.2)
    raise RuntimeError(f"{method} failed: {last}")

def bh(n):
    return rpc("chain_getBlockHash", [n])

def store_at(key, h):
    return rpc("state_getStorage", [key, h])

def u128(hexv):
    if not hexv or hexv == "0x": return None
    return int.from_bytes(bytes.fromhex(hexv[2:])[:16], 'little')

def rate_at(n):
    h = bh(n)
    if not h: return None
    tsb = u128(store_at(TSB, h))
    li = u128(store_at(LDOT_ISSUANCE, h))
    tv = u128(store_at(TVL, h))
    t = u128(store_at(TSNOW, h))
    rate = (tsb / (li + (tv or 0))) if tsb and li else None
    return {"block": n, "tsb": tsb, "ldot_issuance": li, "tvl": tv, "rate": rate,
            "ts_ms": t, "utc": time.strftime('%Y-%m-%d %H:%M', time.gmtime(t/1000)) if t else None}

def main():
    cur = int(rpc("chain_getHeader", [])["number"], 16)
    print("current block:", cur)
    ref = store_at(POOLS0, bh(cur))
    print("pool0 now:", ref[:60], "...")
    ref_rate = rate_at(cur)
    print("rate now:", json.dumps(ref_rate))

    # find last change
    last_change = None
    for delta in [1, 10, 100, 1000, 5000, 10000, 20000, 50000, 100000, 200000, 400000, 800000, 1600000]:
        n = cur - delta
        if n < 1: break
        h = bh(n)
        if not h: continue
        v = store_at(POOLS0, h)
        same = (v == ref)
        print(f"-{delta}: same={same}")
        if not same:
            last_change = n
            break
    if last_change is None:
        print("no change found in range"); return
    lo, hi = last_change, last_change + 800000
    # first block with state == current
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        h = bh(mid)
        v = store_at(POOLS0, h) if h else None
        if v == ref: hi = mid
        else: lo = mid
    print("last-change block (state differs):", lo)
    print("first block with current state    :", hi)
    for n in [lo, hi]:
        r = rate_at(n)
        print("rate at", n, json.dumps(r))

    # rate trajectory
    print("\n=== rate trajectory ===")
    for delta in [0, 500, 2000, 5000, 10000, 20000, 30000, 40000, 50000, 75000, 100000, 150000, 200000, 300000, 500000, 1000000]:
        n = cur - delta
        try:
            r = rate_at(n)
            print(json.dumps(r))
        except Exception as e:
            print(n, "ERR", e)

if __name__ == "__main__":
    main()
