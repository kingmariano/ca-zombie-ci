#!/usr/bin/env python3
"""Fetch tx sender + block timestamp for the largest supply events; crawl Sync logs."""
import json, sys, time, urllib.request

RPC = "https://andromeda.metis.io/?owner=1088"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
       "Content-Type": "application/json"}

def rpc(method, params, tries=6):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, data=payload, headers=HDR)
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.load(r)
            if "error" in d:
                raise RuntimeError(d["error"])
            return d["result"]
        except Exception as e:
            sys.stderr.write(f"retry {i} {method}: {e}\n")
            time.sleep(2 * (i + 1))
    raise RuntimeError("failed " + method)

def txinfo(h):
    t = rpc("eth_getTransactionByHash", [h])
    b = rpc("eth_getBlockByNumber", [t["blockNumber"], False])
    return {"hash": h, "from": t["from"], "to": t["to"], "block": int(t["blockNumber"], 16),
            "ts": int(b["timestamp"], 16), "input_selector": t["input"][:10]}

NAMES = {
    "0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1": "A",
    "0x59051B5F5172b69E66869048Dc69D35dB0B3610d": "B",
    "0x5Ae3ee7fBB3Cb28C17e7ADc3a6Ae605ae2465091": "C",
    "0x9dAbD9257E55230Fa17415BF9a6946085f533a00": "D",
}

if __name__ == "__main__":
    out = {}
    for pair in sys.argv[1:]:
        short = NAMES[pair]
        rows = json.load(open(f"raw/timeline_{pair}.json"))
        # top 14 burns and top 8 mints by value
        burns = sorted([r for r in rows if r["kind"] == "burn"], key=lambda r: -r["val"])[:14]
        mints = sorted([r for r in rows if r["kind"] == "mint"], key=lambda r: -r["val"])[:8]
        sel = burns + mints
        res = []
        for r in sel:
            info = txinfo(r["tx"])
            info.update({"kind": r["kind"], "lp_val": r["val"], "supply_after": r["supply_after"], "cp": r["cp"]})
            res.append(info)
        out[short] = res
        print(f"=== pair {short} top events ===")
        for x in res:
            print(f" {x['kind']:4} blk={x['block']} ts={x['ts']} lp={x['lp_val']/1e18:.9f} from={x['from']} to={x['to']} sel={x['input_selector']} supply_after={x['supply_after']/1e18:.9f} tx={x['hash'][:20]}")
    json.dump(out, open("raw/burner_analysis.json", "w"), indent=1)
