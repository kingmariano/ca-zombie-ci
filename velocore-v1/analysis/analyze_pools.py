#!/usr/bin/env python3
"""Deeper state scan of Velocore V1 pools: code identity, stable flag, names,
actual balances vs reserves (skim excess), LP supply. Read-only."""
import json, urllib.request, time, hashlib

RPC = "https://mainnet.era.zksync.io"
SEL = {
    "stable": "0x22be3de1",
    "name": "0x06fdde03",
    "balanceOf": "0x70a08231",
    "getReserves": "0x0902f1ac",
    "totalSupply": "0x18160ddd",
}
_id = [1000]
def rpc_batch(calls):
    payload = []
    for method, params in calls:
        _id[0] += 1
        payload.append({"jsonrpc": "2.0", "id": _id[0], "method": method, "params": params})
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                res = json.loads(r.read())
            break
        except Exception:
            if attempt == 4: raise
            time.sleep(2 * (attempt + 1))
    if isinstance(res, dict): res = [res]
    out = [None] * len(calls)
    base = payload[0]["id"]
    for item in res:
        out[item["id"] - base] = item.get("result")
    return out

def chunked(lst, n):
    for i in range(0, len(lst), n): yield lst[i:i+n]

def dec_addr(h):
    return "0x" + h[-40:] if h and len(h) >= 42 else None

def dec_uint(h):
    return int(h, 16) if h and h != "0x" else None

def dec_str(h):
    if not h or h == "0x": return None
    try:
        if len(h) > 130:
            off = int(h[2:66], 16); ln = int(h[66+2*off:66+2*off+64], 16)
            return bytes.fromhex(h[66+2*off+64:66+2*off+64+2*ln]).decode("utf-8","replace")
        return bytes.fromhex(h[2:]).rstrip(b"\x00").decode("utf-8","replace")
    except Exception:
        return None

def main():
    d = json.load(open("/home/heisenberg/CA/velocore-v1/analysis/pairs_raw.json"))
    pairs = d["pairs"]
    out = {"block": d["block"], "pairs": []}
    # 1) code for each pair -> group
    codes = {}
    for batch in chunked(pairs, 8):
        res = rpc_batch([("eth_getCode", [p["pair"], "latest"]) for p in batch])
        for p, c in zip(batch, res):
            h = hashlib.sha3_256(c.encode()).hexdigest()[:16] if c else "none"
            codes.setdefault(h, []).append(p["pair"])
            p["code_hash16"] = h
            p["code_len"] = (len(c)-2)//2 if c else 0
    out["code_groups"] = {k: {"count": len(v), "sample": v[0]} for k, v in codes.items()}
    print("code groups:", json.dumps(out["code_groups"], indent=1))
    # 2) stable(), name()
    for batch in chunked(pairs, 10):
        res = rpc_batch([("eth_call", [{"to": p["pair"], "data": SEL["stable"]}, "latest"]) for p in batch])
        res2 = rpc_batch([("eth_call", [{"to": p["pair"], "data": SEL["name"]}, "latest"]) for p in batch])
        for p, s, n in zip(batch, res, res2):
            p["stable"] = (dec_uint(s) == 1) if s and s != "0x" else None
            p["name"] = dec_str(n)
    # 3) balances of pool for token0/token1 -> excess vs reserves
    for batch in chunked(pairs, 10):
        calls = []
        for p in batch:
            for tok in (p["token0"], p["token1"]):
                calls.append(("eth_call", [{"to": tok, "data": SEL["balanceOf"] + p["pair"][2:].zfill(64)}, "latest"]))
        res = rpc_batch(calls)
        for i, p in enumerate(batch):
            b0 = dec_uint(res[2*i]); b1 = dec_uint(res[2*i+1])
            p["balance0"] = str(b0) if b0 is not None else None
            p["balance1"] = str(b1) if b1 is not None else None
    for p in pairs:
        try:
            r0 = int(p.get("reserve0") or 0); r1 = int(p.get("reserve1") or 0)
            b0 = int(p.get("balance0") or 0); b1 = int(p.get("balance1") or 0)
            p["excess0"] = str(max(0, b0 - r0)); p["excess1"] = str(max(0, b1 - r1))
        except Exception:
            pass
    out["pairs"] = pairs
    json.dump(out, open("/home/heisenberg/CA/velocore-v1/analysis/pairs_deep.json","w"), indent=1)
    # summary
    from collections import Counter
    c = Counter(p.get("name","?").split(" - ")[0] for p in pairs)
    print("pool types:", dict(c))
    sk = [p for p in pairs if int(p.get("excess0") or 0) > 0 or int(p.get("excess1") or 0) > 0]
    print("pairs with excess:", len(sk))
    for p in sk[:40]:
        print(" ", p["pair"], p.get("name"), "excess0=", p["excess0"], "excess1=", p["excess1"])

if __name__ == "__main__":
    main()
