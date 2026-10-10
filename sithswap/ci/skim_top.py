#!/usr/bin/env python3
"""Quick skim-able excess check on top pools (read-only)."""
import json, os, sys, time, urllib.request
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis"))
from sn import selector

RPCS = ["https://api.cartridge.gg/x/starknet/mainnet", "https://starknet.drpc.org"]
_last = [0.0]
def rpc(method, params, tries=6):
    last = None
    for a in range(tries):
        url = RPCS[a % len(RPCS)]
        dt = time.time() - _last[0]
        if dt < 0.4:
            time.sleep(0.4 - dt)
        _last[0] = time.time()
        try:
            body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                j = json.loads(r.read())
            if "error" in j:
                last = j["error"]; time.sleep(0.5); continue
            return j["result"]
        except Exception as e:
            last = str(e); time.sleep(0.6)
    raise RuntimeError(str(last))

def call(addr, fn, cd=None, block="latest"):
    bid = block if isinstance(block, (str, dict)) else {"block_number": int(block)}
    return rpc("starknet_call", {"request": {"contract_address": hex(addr), "entry_point_selector": selector(fn),
                "calldata": [hex(x) for x in (cd or [])]}, "block_id": bid})

def u256(f):
    return int(f[0], 16) + (int(f[1], 16) << 128)

def main():
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    d = json.load(open(os.path.join(base, "analysis", "pairs_priced.json")))
    pairs = [p for p in d["pairs"] if p.get("usd", 0) > 1]
    pairs.sort(key=lambda p: -p["usd"])
    blk = rpc("starknet_blockNumber", [])
    res = []
    for p in pairs[:8]:
        try:
            pa = int(p["pair"], 16)
            r0 = u256(call(pa, "getReserve0", None, blk)); r1 = u256(call(pa, "getReserve1", None, blk))
            t0, t1 = [int(t, 16) for t in p["tokens"]]
            b0 = u256(call(t0, "balanceOf", [pa], blk)); b1 = u256(call(t1, "balanceOf", [pa], blk))
            e0 = max(0, b0 - r0); e1 = max(0, b1 - r1)
            res.append({"pid": p["pid"], "pair": p["pair"], "excess0": e0, "excess1": e1, "usd": p["usd"]})
            print("pid=%3d excess0=%d excess1=%d" % (p["pid"], e0, e1), flush=True)
        except Exception as e:
            print("err", p["pid"], str(e)[:80], flush=True)
    json.dump({"block": blk, "rows": res}, open(os.path.join(base, "ci-out", "skim_excess.json"), "w"), indent=1)
    print("block", blk, "checked", len(res), "with_excess", len([r for r in res if r["excess0"] or r["excess1"]]))

if __name__ == "__main__":
    main()
