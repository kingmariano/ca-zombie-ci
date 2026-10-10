#!/usr/bin/env python3
"""Enumerate StarkDeFi factory pairs on Starknet mainnet (read-only).

Outputs analysis/pairs_raw.jsonl with per-pair snapshot + LP total_supply.
Uses keyless public RPC endpoints only; no secrets.
"""
import json, urllib.request, urllib.error, os, sys, time
from concurrent.futures import ThreadPoolExecutor, as_completed

ENDPOINTS = [
    "https://starknet-rpc.publicnode.com",
    "https://api.cartridge.gg/x/starknet/mainnet",
    "https://starknet.api.onfinality.io/public",
]

FACTORY = "0x02721f5ab785ae5E13b276ca9d41e859B7b150440A288A7826Ba5E27Dd05E08e"
SEL_ALL_PAIRS = "0x374f0b8d247fc1c7adbf5d9ea816d0591f2ab72a646c235f02dabe91514c4de"
SEL_SNAPSHOT = "0x277e793564bc5ba0713b610c743ab0d819d9580fcae7c67b4c6f835fb9ee500"
SEL_TOTAL_SUPPLY = "0x1557182e4359a1f0c6301278e8f5b35a776ab58d39892581e357578fb287836"

OUTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis")
os.makedirs(OUTDIR, exist_ok=True)


def rpc(method, params, ep_idx=0, timeout=45, retries=4):
    last = None
    for i in range(retries):
        url = ENDPOINTS[(ep_idx + i) % len(ENDPOINTS)]
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
                headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"},
            )
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.loads(r.read().decode())
            if "result" in out:
                return out["result"]
            last = out
        except Exception as e:
            last = repr(e)
        time.sleep(0.7 * (i + 1))
    raise RuntimeError(f"rpc failed: {method} {last}")


def call(addr, sel, calldata=None, block="latest"):
    return rpc("starknet_call", [{
        "contract_address": addr,
        "entry_point_selector": sel,
        "calldata": calldata or [],
    }, block])


def u256(felts, i):
    return int(felts[i], 16) + (int(felts[i + 1], 16) << 128)


def main():
    block = rpc("starknet_blockNumber", [])
    print(f"latest block: {block}", flush=True)
    res = call(FACTORY, SEL_ALL_PAIRS, block={"block_number": block})
    count = int(res[0], 16)
    arr_len = int(res[1], 16)
    pairs = res[2:2 + arr_len]
    assert count == arr_len == len(pairs), (count, arr_len, len(pairs))
    print(f"pairs: {count}", flush=True)

    out_path = os.path.join(OUTDIR, "pairs_raw.jsonl")
    results = {}

    def fetch_pair(p):
        snap = call(p, SEL_SNAPSHOT, block={"block_number": block})
        supply = call(p, SEL_TOTAL_SUPPLY, block={"block_number": block})
        return p, snap, supply

    done = 0
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(fetch_pair, p): p for p in pairs}
        for f in as_completed(futs):
            p = futs[f]
            try:
                p, snap, supply = f.result()
                rec = {
                    "pair": p,
                    "token0": snap[0],
                    "token1": snap[1],
                    "decimal0": str(u256(snap, 2)),
                    "decimal1": str(u256(snap, 4)),
                    "reserve0": str(u256(snap, 6)),
                    "reserve1": str(u256(snap, 8)),
                    "is_stable": bool(int(snap[10], 16)),
                    "fee_tier": int(snap[11], 16),
                    "lp_total_supply": str(int(supply[0], 16) + (int(supply[1], 16) << 128)),
                }
                results[p] = rec
            except Exception as e:
                results[p] = {"pair": p, "error": repr(e)}
            done += 1
            if done % 25 == 0:
                print(f"  {done}/{count}", flush=True)

    # order by factory order
    with open(out_path, "w") as fh:
        for p in pairs:
            fh.write(json.dumps(results[p]) + "\n")
    meta = {
        "block": block,
        "factory": FACTORY,
        "pair_count": count,
        "fetched_ok": sum(1 for r in results.values() if "error" not in r),
    }
    with open(os.path.join(OUTDIR, "pairs_meta.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print(json.dumps(meta), flush=True)


if __name__ == "__main__":
    main()
