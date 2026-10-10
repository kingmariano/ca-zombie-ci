#!/usr/bin/env python3
"""Behavioral probe: call pair.skim(to) via starknet_call on every quiet pair.

Discriminates the pre-fix vs post-fix skim:
  quiet pair (b0==r0, b1==r1):
    post-fix skim: transfers 0 and 0  -> SUCCESS always
    pre-fix  skim: balance1 = b0; transfers (b0 - r1) of token1
                   -> r0 < r1: u256 underflow REVERT
                   -> r0 > r1: success iff r0-r1 <= r1 (r0 <= 2*r1) else ERC20 revert
Read-only; starknet_call discards state.
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
SEL_SKIM = "0x3dd12614b076872dd4f330f78e0121959fb5511add6c672bcb20ea237c376f2"
TO = "0x1234567890abcdef1234567890abcdef12345678"  # dummy recipient


def rpc(method, params, timeout=45, retries=5):
    last = None
    for i in range(retries):
        url = ENDPOINTS[i % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(url, data=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),
                                         headers={"Content-Type":"application/json","User-Agent":"Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.loads(r.read().decode())
            return out
        except Exception as e:
            last = repr(e)
        time.sleep(0.6)
    return {"error": {"message": str(last)}}


def main():
    block = rpc("starknet_blockNumber", [])["result"]
    print("block", block, flush=True)
    recs = [json.loads(l) for l in open(os.path.join(OUT, "pair_balances.jsonl"))]
    quiet = [r for r in recs if r.get("b0") == r.get("r0") and r.get("b1") == r.get("r1")]
    print("quiet:", len(quiet), flush=True)

    def probe(r):
        out = rpc("starknet_call", [{"contract_address": r["pair"], "entry_point_selector": SEL_SKIM,
                                     "calldata": [TO]}, {"block_number": block}])
        if "result" in out:
            return r, "OK", ""
        err = out.get("error", {})
        data = err.get("data", {}) if isinstance(err, dict) else {}
        reason = data.get("revert_error", err.get("message", str(err))) if isinstance(data, dict) else str(err)
        return r, "REVERT", str(reason)[:200]

    rows = []
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = [ex.submit(probe, r) for r in quiet]
        for i, f in enumerate(as_completed(futs)):
            rows.append(f.result())
            if (i+1) % 60 == 0:
                print(f"  {i+1}/{len(quiet)}", flush=True)

    with open(os.path.join(OUT, "skim_probe.jsonl"), "w") as fh:
        for r, status, reason in rows:
            fh.write(json.dumps({**r, "skim_status": status, "skim_revert": reason}) + "\n")

    # summary per class and reserve relation
    from collections import Counter, defaultdict
    summ = defaultdict(Counter)
    for r, status, reason in rows:
        rel = "r0<r1" if r["r0"] < r["r1"] else ("r0>r1" if r["r0"] > r["r1"] else "r0==r1")
        summ[r["class_hash"]][(rel, status)] += 1
    for ch, c in summ.items():
        print(ch[:18], dict(c))
    print(json.dumps({"block": block}, indent=1))


if __name__ == "__main__":
    main()
