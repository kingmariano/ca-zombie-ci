#!/usr/bin/env python3
"""Enumerate holders of a token via GoldRush, then verify balances on-chain
via public RPC batches. Classify contract vs EOA via eth_getCode."""
import json, urllib.request, os, sys, time

def rpc_batch(url, calls):
    batch = [{"jsonrpc":"2.0","id":i,"method":m,"params":p} for i,(m,p) in enumerate(calls)]
    req = urllib.request.Request(url, data=json.dumps(batch).encode(),
        headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (research)"})
    out = json.load(urllib.request.urlopen(req, timeout=90))
    return {r["id"]: r.get("result", r.get("error")) for r in out}

def goldrush_holders(chain, token, key):
    holders = []
    page = 0
    while True:
        url = f"https://api.covalenthq.com/v1/{chain}/tokens/{token}/token_holders_v2/?page-size=100&page-number={page}"
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {key}",
            "User-Agent": "Mozilla/5.0 (research; read-only)"})
        d = json.load(urllib.request.urlopen(req, timeout=60))
        items = (d.get("data") or {}).get("items") or []
        if not items: break
        holders.extend(items)
        page += 1
        if page > 30: break
        time.sleep(0.3)
    return holders

def main():
    key = None
    with open("/home/heisenberg/CA/.env") as f:
        for line in f:
            if line.startswith("GOLD_RUSH_API_KEY="):
                key = line.strip().split("=",1)[1]
    token = sys.argv[1]
    chain = sys.argv[2] if len(sys.argv)>2 else "137"
    rpc = sys.argv[3] if len(sys.argv)>3 else "https://polygon-bor-rpc.publicnode.com"
    hs = goldrush_holders(chain, token, key)
    print(f"# goldrush raw holders: {len(hs)}", file=sys.stderr)
    addrs = [h["address"] for h in hs]
    # dedupe
    addrs = list(dict.fromkeys(addrs))
    # on-chain balances in batches of 20
    res = {}
    for i in range(0, len(addrs), 20):
        chunk = addrs[i:i+20]
        calls = []
        for a in chunk:
            data = "0x70a08231" + "0"*24 + a[2:].lower()
            calls.append(("eth_call", [{"to": token, "data": data}, "latest"]))
            calls.append(("eth_getCode", [a, "latest"]))
        out = rpc_batch(rpc, calls)
        for j,a in enumerate(chunk):
            bal = out.get(2*j)
            code = out.get(2*j+1)
            bal = int(bal,16) if isinstance(bal,str) and bal != "0x" else 0
            csize = (len(code)-2)//2 if isinstance(code,str) else -1
            res[a] = (bal, csize)
        time.sleep(0.2)
    total = 0
    rows = []
    for a,(bal,csize) in res.items():
        if bal > 0:
            total += bal
            rows.append((a,bal,csize))
    rows.sort(key=lambda r:-r[1])
    print(f"# holders with live balance: {len(rows)}", file=sys.stderr)
    print("address,balance_wei,code_size")
    for a,bal,csize in rows:
        print(f"{a},{bal},{csize}")
    print(f"# sum_wei={total}", file=sys.stderr)

if __name__ == "__main__":
    main()
