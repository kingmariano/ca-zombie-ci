#!/usr/bin/env python3
"""Holder + redeemability check for scDEI and scBOO(a25f). Chunked Mint/Redeem fetch, then
membership + redeem(1) simulation."""
import json, os, sys, time, urllib.request

POOL = ["https://rpcapi.fantom.network", "https://fantom.api.onfinality.io/public", "https://fantom.drpc.org"]
_i = [0]

def post(payload):
    last = None
    for a in range(9):
        url = POOL[_i[0] % len(POOL)]
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
        try:
            return json.loads(urllib.request.urlopen(req, timeout=60).read())
        except Exception as e:
            last = e; _i[0] += 1; time.sleep(0.7 + a * 0.3)
    raise last

MINT = "0x4c209b5fc8ad50758f13e2e1088ba56a560dff690a1c6fef26394f4c03821c4f"
REDEEM = "0xe5b754fb1abb7f01b499791d0b820ae3b6af3424ac1c59768edb53f4ec31a929"
CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"

def get_logs(addr, topic, lo, hi):
    r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_getLogs",
              "params": [{"fromBlock": hex(lo), "toBlock": hex(hi), "address": addr, "topics": [topic]}]})
    if "result" not in r: raise RuntimeError(str(r)[:150])
    return r["result"]

def holders_of(addr):
    latest = int(post({"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []})["result"], 16)
    out = {}
    lo = 0
    chunk = 5_000_000
    while lo < latest:
        hi = min(lo + chunk, latest)
        try:
            logs = get_logs(addr, MINT, lo, hi) + get_logs(addr, REDEEM, lo, hi)
        except Exception as e:
            if chunk > 200_000:
                chunk //= 2
                continue
            print("give up", addr, lo, hi, e, file=sys.stderr)
            lo = hi + 1
            continue
        for lg in logs:
            t = lg["topics"][0]
            w0 = lg["data"][2:][:64]
            a = "0x" + w0[-40:]
            amt = int(lg["data"][2:][64:128], 16)  # mintAmount or redeemAmount (underlying)
            out.setdefault(a, 0)
            out[a] += amt if t == MINT else -amt
        lo = hi + 1
    return out, latest

def fw(r):
    return int(r[2:66], 16) if isinstance(r, str) and len(r) >= 66 else None

def main():
    targets = {"scDEI": "0x68c102aba11f5e086c999d99620c78f5bc30ecd8",
               "scBOO_a25f": "0xa25f9ffd7855fc350a103d91ab7c906d6bf1977d"}
    allout = {}
    for name, addr in targets.items():
        net, latest = holders_of(addr)
        print(name, "candidate addrs:", len(net), "latest", latest, file=sys.stderr)
        # current cToken balances
        rows = []
        for a in list(net)[:400]:
            b = fw(post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                         "params": [{"to": addr, "data": "0x70a08231" + a[2:].rjust(64, "0")}, "latest"]}).get("result"))
            if b:
                assets = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                               "params": [{"to": CTRL, "data": "0xabfceffc" + a[2:].rjust(64, "0")}, "latest"]}).get("result")
                member = isinstance(assets, str) and addr.lower() in assets.lower()
                r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call",
                          "params": [{"to": addr, "data": "0xdb006a75" + hex(1)[2:].rjust(64, "0"), "from": a}, "latest"]})
                res = r.get("result")
                can = isinstance(res, str) and int(res, 16) == 0
                rows.append({"addr": a, "ctokens": b, "member": member, "can_redeem": can})
        allout[name] = {"market": addr, "latest": latest, "holders": rows}
        ok = sum(x["ctokens"] for x in rows if x["can_redeem"])
        bad = sum(x["ctokens"] for x in rows if not x["can_redeem"])
        print(f"{name}: holders={len(rows)} redeemable_ct={ok/1e8:.4f} stuck_ct={bad/1e8:.4f}", file=sys.stderr)
    json.dump(allout, open("/home/heisenberg/CA/scream/analysis/other_markets_holders.json", "w"), indent=2)
    print("done")

if __name__ == "__main__":
    main()
