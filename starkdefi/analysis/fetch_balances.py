#!/usr/bin/env python3
"""Fetch real token balances for all StarkDeFi pairs + behavioral skim probe per class group.

Read-only: starknet_call only (no state change).
"""
import json, urllib.request, os, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.api.onfinality.io/public",
]
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "analysis")
FACTORY = "0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e"
SEL_BALANCE_OF = "0x2e4263afad30923c891518314c3c95dbe830a16874e8abc5777a9a20b54c76e"
SEL_SKIM = "0x3dd12614b076872dd4f330f78e0121959fb5511add6c672bcb20ea237c376f2"
SEL_SNAPSHOT = "0x277e793564bc5ba0713b610c743ab0d819d9580fcae7c67b4c6f835fb9ee500"


def rpc(method, params, timeout=45, retries=5):
    last = None
    for i in range(retries):
        url = ENDPOINTS[i % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.loads(r.read().decode())
            if "result" in out:
                return out["result"]
            last = out
        except Exception as e:
            last = repr(e)
        time.sleep(0.5)
    raise RuntimeError(f"{method}: {last}")


def call(addr, sel, cd, block):
    return rpc("starknet_call", [{"contract_address": addr, "entry_point_selector": sel, "calldata": cd}, block])


def main():
    block = rpc("starknet_blockNumber", [])
    print("block", block, flush=True)
    pairs = [json.loads(l) for l in open(os.path.join(OUT, "pairs_raw.jsonl"))]
    chs = json.load(open(os.path.join(OUT, "factory_state.json")))["pair_class_hashes"]

    def fetch(p):
        r0 = call(p["token0"], SEL_BALANCE_OF, [p["pair"]], {"block_number": block})
        b0 = int(r0[0], 16) + (int(r0[1], 16) << 128)
        r = call(p["token1"], SEL_BALANCE_OF, [p["pair"]], {"block_number": block})
        b1 = int(r[0], 16) + (int(r[1], 16) << 128)
        return {"pair": p["pair"], "token0": p["token0"], "token1": p["token1"],
                "r0": int(p["reserve0"]), "r1": int(p["reserve1"]), "b0": b0, "b1": b1,
                "class_hash": chs.get(p["pair"])}

    recs = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(fetch, p) for p in pairs]
        for i, f in enumerate(as_completed(futs)):
            try:
                recs.append(f.result())
            except Exception as e:
                recs.append({"error": repr(e)})
            if (i+1) % 50 == 0:
                print(f"  {i+1}/{len(pairs)}", flush=True)
    with open(os.path.join(OUT, "pair_balances.jsonl"), "w") as fh:
        for r in recs:
            fh.write(json.dumps(r) + "\n")
    quiet = [r for r in recs if r.get("b0") == r.get("r0") and r.get("b1") == r.get("r1")]
    print("fetched:", len(recs), "quiet:", len(quiet), flush=True)
    from collections import Counter
    print("quiet by class:", Counter(r["class_hash"] for r in quiet))
    print(json.dumps({"block": block}, indent=1))


if __name__ == "__main__":
    main()
