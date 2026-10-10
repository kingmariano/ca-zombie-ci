#!/usr/bin/env python3
"""Scan ERC20 Transfer events from a given address (keys = [selector, from])."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, selector_from_name, block_number  # noqa


def scan(from_addr, token, lo, hi, range_size=1_000_000, chunk=1000):
    sel = selector_from_name("Transfer")
    out = []
    l = lo
    while l <= hi:
        h = min(l + range_size - 1, hi)
        token_ct = None
        while True:
            f = {
                "from_block": {"block_number": l},
                "to_block": {"block_number": h},
                "address": token,
                "keys": [[sel], [from_addr]],
                "chunk_size": chunk,
            }
            if token_ct:
                f["continuation_token"] = token_ct
            r = rpc("starknet_getEvents", {"filter": f})
            if "result" not in r:
                print(f"  ERR [{l}-{h}]: {json.dumps(r)[:150]}")
                break
            res = r["result"]
            out.extend(res.get("events", []))
            token_ct = res.get("continuation_token")
            if not token_ct:
                break
        l = h + 1
    return out


if __name__ == "__main__":
    from_addr = sys.argv[1]
    token = sys.argv[2]
    lo = int(sys.argv[3])
    hi = int(sys.argv[4])
    out = scan(from_addr, token, lo, hi)
    fn = sys.argv[5] if len(sys.argv) > 5 else "transfers.json"
    with open(os.path.join(os.path.dirname(__file__), fn), "w") as f:
        json.dump(out, f)
    print("saved", fn, len(out))
    for e in out:
        print(e["block_number"], e["keys"][2] if len(e["keys"]) > 2 else "?", e["data"][:2])
