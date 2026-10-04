#!/usr/bin/env python3
"""Reconstruct LP totalSupply timeline per pair from mint/burn Transfer logs."""
import json, sys
from collections import defaultdict

ZERO = "0x0000000000000000000000000000000000000000000000000000000000000000"

NAMES = {
    "0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1": "A",
    "0x59051B5F5172b69E66869048Dc69D35dB0B3610d": "B",
    "0x5Ae3ee7fBB3Cb28C17e7ADc3a6Ae605ae2465091": "C",
    "0x9dAbD9257E55230Fa17415BF9a6946085f533a00": "D",
}

def load(pair, kind):
    short = NAMES[pair]
    d = json.load(open(f"raw/rpc_{short}_{kind}s.json"))
    out = []
    for l in d:
        val = int(l["data"], 16)
        blk = int(l["blockNumber"], 16)
        idx = int(l["logIndex"], 16)
        tx = l["transactionHash"]
        topics = l["topics"]
        if kind == "mint":
            cp = "0x" + topics[2][-40:]  # to
        else:
            cp = "0x" + topics[1][-40:]  # from (the pair normally)
            # pair burns: from = pair address, to = 0x0
        out.append(dict(block=blk, idx=idx, val=val, tx=tx, cp=cp, kind=kind))
    return out

def timeline(pair):
    evs = load(pair, "mint") + load(pair, "burn")
    evs.sort(key=lambda e: (e["block"], e["idx"]))
    supply = 0
    rows = []
    for e in evs:
        supply += e["val"] if e["kind"] == "mint" else -e["val"]
        e["supply_after"] = supply
        rows.append(e)
    return rows

for pair in sys.argv[1:]:
    rows = timeline(pair)
    print(f"\n########## pair {pair}: {len(rows)} mint/burn events")
    print(f"final supply from logs: {rows[-1]['supply_after'] if rows else 0}")
    # first events
    for e in rows[:6]:
        print(f"  FIRST {e['kind']:4} blk={e['block']} val={e['val']/1e18:.9f} cp={e['cp']} tx={e['tx'][:18]}")
    # top 15 value events
    top = sorted(rows, key=lambda e: -e["val"])[:18]
    print("  top value events:")
    for e in sorted(top, key=lambda e: e["block"]):
        print(f"   {e['kind']:4} blk={e['block']} val={e['val']/1e18:.9f} supply_after={e['supply_after']/1e18:.9f} cp={e['cp']} tx={e['tx'][:18]}")
    # min supply dip points around biggest burns
    # last 12 events
    print("  last events:")
    for e in rows[-12:]:
        print(f"   {e['kind']:4} blk={e['block']} val={e['val']/1e18:.9f} supply_after={e['supply_after']/1e18:.9f} cp={e['cp']} tx={e['tx'][:18]}")
    # save compact
    json.dump(rows, open(f"raw/timeline_{pair}.json", "w"))
