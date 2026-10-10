#!/usr/bin/env python3
"""Quantify skim-able excess (balance - reserve) on pairs — anyone can take it via skim(to)."""
import json, os, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis"))
import urllib.request

RPCS = ["https://api.cartridge.gg/x/starknet/mainnet", "https://starknet.drpc.org"]
_last = [0.0]
def rpc(method, params, tries=8):
    last = None
    for attempt in range(tries):
        url = RPCS[attempt % len(RPCS)]
        dt = time.time() - _last[0]
        if dt < 0.3:
            time.sleep(0.3 - dt)
        _last[0] = time.time()
        try:
            body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 research"})
            with urllib.request.urlopen(req, timeout=45) as r:
                j = json.loads(r.read())
            if "error" in j:
                last = j["error"]; time.sleep(0.5 + attempt * 0.7); continue
            return j["result"]
        except Exception as e:
            last = str(e); time.sleep(0.7 + attempt * 0.8)
    raise RuntimeError(f"{method} failed: {last}")

from sn import selector
def call(addr, fn, cd=None, block="latest"):
    res = rpc("starknet_call", {"request": {"contract_address": hex(addr), "entry_point_selector": selector(fn),
              "calldata": [hex(x) for x in (cd or [])]}, "block_id": block})
    return res

def u256(f):
    return int(f[0], 16) + (int(f[1], 16) << 128)

def main():
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    d = json.load(open(os.path.join(base, "analysis", "pairs_priced.json")))
    meta = d["meta"]; pairs = d["pairs"]
    pairs = [p for p in pairs if p.get("usd", 0) > 1]
    pairs.sort(key=lambda p: -p["usd"])
    top = pairs[:40]
    block = rpc("starknet_blockNumber", [])
    rows = []
    for p in top:
        try:
            pa = int(p["pair"], 16)
            r0 = u256(call(pa, "getReserve0", None, block))
            r1 = u256(call(pa, "getReserve1", None, block))
            t0, t1 = [int(t, 16) for t in p["tokens"]]
            b0 = u256(call(t0, "balanceOf", [hex(pa)], block))
            b1 = u256(call(t1, "balanceOf", [hex(pa)], block))
            e0 = max(0, b0 - r0); e1 = max(0, b1 - r1)
            rows.append({"pair": p["pair"], "pid": p["pid"], "excess0": e0, "excess1": e1,
                         "bal0": b0, "bal1": b1, "res0": r0, "res1": r1})
            if e0 or e1:
                print(f"EXCESS pid={p['pid']} {p['pair'][:14]} excess0={e0} excess1={e1}", flush=True)
        except Exception as e:
            rows.append({"pair": p.get("pair"), "error": str(e)[:120]})
    n_excess = len([r for r in rows if r.get("excess0") or r.get("excess1")])
    print(f"block={block} checked={len(rows)} pools_with_excess={n_excess}", flush=True)
    outp = os.path.join(base, "ci-out")
    os.makedirs(outp, exist_ok=True)
    json.dump({"block": block, "rows": rows, "pools_with_excess": n_excess}, open(os.path.join(outp, "skim_excess.json"), "w"), indent=1)

if __name__ == "__main__":
    main()
