#!/usr/bin/env python3
"""Focused: for each scLINK borrower candidate, fetch balanceOf, debt, assetsIn, liquidity."""
import json, time, urllib.request, sys

RPC = "https://rpcapi.fantom.network"
CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"
LINKM = "0x2359012ebe36cca231203d78b914284947b58aa3"

SEL = {
    "balanceOf": "0x70a08231",
    "borrowBalanceCurrent": "0x17bfdfbc",
    "getAssetsIn": "0xabfceffc",
    "getAccountLiquidity": "0x5ec88c79",
    "borrowIndex": "0xaa5af0fd",
    "exchangeRateCurrent": "0xbd6d894d",
}

def pad(a): return a[2:].lower().rjust(64, "0")

def post(payload):
    req = urllib.request.Request(RPC, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
    for a in range(5):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=60).read())
        except Exception:
            if a == 4: raise
            time.sleep(1)

def batch(calls):
    out = []
    for i in range(0, len(calls), 10):
        chunk = calls[i:i+10]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(chunk)]
        resp = post(payload)
        by_id = {r["id"]: r for r in resp}
        for j in range(len(chunk)):
            r = by_id.get(j, {})
            out.append(r.get("result") if "result" in r else {"error": r.get("error")})
    return out

def call(to, sel, arg=None):
    data = sel + (pad(arg) if arg else "")
    return ["eth_call", [{"to": to, "data": data}, "latest"]]

def decode_addr_arr(h):
    if not isinstance(h, str) or len(h) < 130:
        return h
    b = h[2:]
    off = int(b[:64], 16)
    ln = int(b[off*2:off*2+64], 16)
    out = []
    for i in range(ln):
        out.append("0x" + b[(off+32+i*32)*2+24:(off+32+i*32+32)*2])
    return out

def main():
    actors = json.load(open("/home/heisenberg/CA/scream/analysis/sclink_actors.json"))
    borrowers = [b["addr"] for b in actors["borrowers"]]
    print("borrowers:", len(borrowers), flush=True)

    bn = int(post({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"], 16)
    print("block", bn, flush=True)

    # balances
    res = batch([call(LINKM, SEL["balanceOf"], a) for a in borrowers])
    bal = {a: (int(r, 16) if isinstance(r, str) and r != "0x" else 0) for a, r in zip(borrowers, res)}
    # debt
    res = batch([call(LINKM, SEL["borrowBalanceCurrent"], a) for a in borrowers])
    debt = {a: (int(r, 16) if isinstance(r, str) and r != "0x" else None) for a, r in zip(borrowers, res)}
    # assets in
    res = batch([call(CTRL, SEL["getAssetsIn"], a) for a in borrowers])
    assets = {a: decode_addr_arr(r) for a, r in zip(borrowers, res)}
    # liquidity
    res = batch([call(CTRL, SEL["getAccountLiquidity"], a) for a in borrowers])
    liq = {}
    for a, r in zip(borrowers, res):
        if isinstance(r, str) and len(r) >= 194:
            b = r[2:]
            liq[a] = {"err": int(b[:64], 16), "liquidity": int(b[64:128], 16), "shortfall": int(b[128:192], 16)}
        else:
            liq[a] = {"error": r}

    print("\n== borrowers with debt > 0:")
    rows = []
    for a in borrowers:
        d = debt.get(a)
        if d:
            rows.append((d, a, bal.get(a, 0), assets.get(a), liq.get(a)))
    for d, a, b, aset, lq in sorted(rows, reverse=True):
        print(f"{a} debt={d/1e18:.6f} scLINKbal={b/1e8:.4f} assets={aset} liq={lq}")

    json.dump({"block": bn, "rows": [{"addr": a, "debt": d, "bal": b, "assets": aset, "liq": lq} for d, a, b, aset, lq in rows]},
              open("/home/heisenberg/CA/scream/analysis/sclink_borrowers.json", "w"), indent=2)

if __name__ == "__main__":
    main()
