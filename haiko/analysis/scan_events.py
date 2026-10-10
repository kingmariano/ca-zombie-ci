#!/usr/bin/env python3
"""Generic Starknet event scanner with pagination + range chunking."""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, block_number, selector_from_name  # noqa


def scan_events(address, keys, from_block, to_block, chunk_size=1000, range_size=2_000_000, verbose=True,
                max_pages=200, stall_break=3):
    """Scan events, returning list. keys = list of lists (each position an OR-set)."""
    out = []
    lo = from_block
    while lo <= to_block:
        hi = min(lo + range_size - 1, to_block)
        token = None
        pages = 0
        stalls = 0
        prev_len = len(out)
        while True:
            f = {
                "from_block": {"block_number": lo},
                "to_block": {"block_number": hi},
                "address": address,
                "keys": keys,
                "chunk_size": chunk_size,
            }
            if token:
                f["continuation_token"] = token
            t0 = time.time()
            r = rpc("starknet_getEvents", {"filter": f})
            dt = time.time() - t0
            if "result" not in r:
                if verbose:
                    print(f"  [{lo}-{hi}] ERR {json.dumps(r)[:200]} ({dt:.1f}s)", flush=True)
                break
            res = r["result"]
            evs = res.get("events", [])
            out.extend(evs)
            pages += 1
            token = res.get("continuation_token")
            if len(out) == prev_len:
                stalls += 1
            else:
                stalls = 0
            prev_len = len(out)
            if verbose:
                print(f"  [{lo}-{hi}] page{pages}: +{len(evs)} (total {len(out)}) {dt:.1f}s", flush=True)
            if not token or pages >= max_pages or stalls >= stall_break:
                if stalls >= stall_break:
                    print(f"  [{lo}-{hi}] stall-break after {pages} pages", flush=True)
                break
        lo = hi + 1
    return out


if __name__ == "__main__":
    addr = sys.argv[1]
    evname = sys.argv[2]
    from_block = int(sys.argv[3])
    to_block = int(sys.argv[4]) if len(sys.argv) > 4 else block_number()
    keys = [[selector_from_name(evname)]] if evname != "any" else []
    out = scan_events(addr, keys, from_block, to_block)
    fn = f"events_{evname}.json"
    with open(os.path.join(os.path.dirname(__file__), fn), "w") as f:
        json.dump(out, f)
    print("saved", fn, len(out))
