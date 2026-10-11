#!/usr/bin/env python3
"""Reconstruct the LP holder set for every 10KSwap pair by replaying LP token
Transfer events from genesis (public RPC, key-filtered, paginated per spec 0.10:
continuation_token lives INSIDE the filter object). Read-only.

Also records Mint/Burn event timelines (LP activity).
Writes analysis/lp_holders.json
"""
import json, sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sn

D = os.path.dirname(os.path.abspath(__file__))
SEL = {n: sn.selector(n) for n in ("Transfer", "Mint", "Burn")}


def fetch_events(addresses, chunk=5000):
    """Single paginated scan over `addresses` (no key filter - the public nodes' key
    filter is unreliable; we classify client-side). Token goes INSIDE the filter."""
    evs = []
    tok = None
    pages = 0
    while True:
        filt = {"from_block": {"block_number": 0}, "to_block": {"block_number": 99999999},
                "address": addresses, "chunk_size": chunk}
        if tok:
            filt["continuation_token"] = tok
        r = sn.rpc("starknet_getEvents", {"filter": filt}, timeout=180)
        got = r.get("events", [])
        evs.extend(got)
        tok = r.get("continuation_token")
        pages += 1
        if pages % 5 == 0 or not tok:
            print(f"   ... page {pages}, {len(evs)} events, token={'y' if tok else 'n'}", flush=True)
        if not tok:
            break
    return evs, pages


def main():
    r1 = json.load(open(os.path.join(D, "recon1.json")))
    pairs = r1["pairs"]
    blk = sn.rpc("starknet_blockNumber", [])
    out = {"block": blk, "pairs": {p: {"transfer_events": 0, "holders": {},
                                       "mint_events": 0, "burn_events": 0} for p in pairs}}
    t0 = time.time()
    evs, pages = fetch_events(pairs)
    print(f"fetched {len(evs)} events in {pages} pages, {time.time()-t0:.1f}s", flush=True)

    for e in evs:
        addr = e["from_address"]
        key0 = e["keys"][0]
        d = [int(x, 16) for x in e["data"]]
        if key0 == SEL["Transfer"]:
            frm, to = d[0], d[1]
            val = d[2] + (d[3] << 128) if len(d) >= 4 else d[2]
            rec = out["pairs"][addr]
            rec["transfer_events"] += 1
            if frm != to:
                if frm != 0:
                    rec.setdefault("_bal", {})[hex(frm)] = rec.get("_bal", {}).get(hex(frm), 0) - val
                if to != 0:
                    rec.setdefault("_bal", {})[hex(to)] = rec.get("_bal", {}).get(hex(to), 0) + val
        elif key0 == SEL["Mint"]:
            rec = out["pairs"][addr]
            rec["mint_events"] += 1
            b = int(e["block_number"])
            rec["mint_last_block"] = max(rec.get("mint_last_block", 0), b)
            rec["mint_first_block"] = min(rec.get("mint_first_block", 10**9), b)
        elif key0 == SEL["Burn"]:
            rec = out["pairs"][addr]
            rec["burn_events"] += 1
            b = int(e["block_number"])
            rec["burn_last_block"] = max(rec.get("burn_last_block", 0), b)
            rec["burn_first_block"] = min(rec.get("burn_first_block", 10**9), b)

    for p in pairs:
        rec = out["pairs"][p]
        bal = rec.pop("_bal", {})
        holders = {k: v for k, v in bal.items() if v > 0}
        rec["holders"] = dict(sorted(holders.items(), key=lambda x: -x[1]))
        rec["holder_count"] = len(holders)
        print(f"{p[:14]} transfers={rec['transfer_events']} holders={rec['holder_count']} "
              f"mint={rec['mint_events']} (last {rec.get('mint_last_block')}) "
              f"burn={rec['burn_events']} (last {rec.get('burn_last_block')})", flush=True)

    with open(os.path.join(D, "lp_holders.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("wrote lp_holders.json", flush=True)


if __name__ == "__main__":
    main()
