#!/usr/bin/env python3
"""Enumerate all pairs of arkadiko-swap-v2-1 and dump live pair state via call-read."""
import json
import os
import sys
from clarity import call_read

HERE = os.path.dirname(os.path.abspath(__file__))
EVID = os.path.join(HERE, "..", "evidence")

SWAP = "SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR.arkadiko-swap-v2-1"
SENDER = "SP2C2YFP12AJZB4MABJBAJ55XECVS7E4PMMZ89YZR"

def main():
    out = {"contract": SWAP, "pairs": []}
    cnt = call_read(SWAP, "get-pair-count", [], SENDER)
    out["pair_count_raw"] = cnt
    n = cnt["decoded"]["ok"]
    for i in range(1, n + 1):
        pc = call_read(SWAP, "get-pair-contracts", [f"uint:{i}"], SENDER)
        pair = pc["decoded"]
        tx, ty = pair["token-x"], pair["token-y"]
        det = call_read(SWAP, "get-pair-details", [f"principal:{tx}", f"principal:{ty}"], SENDER)
        rec = {"pair_id": i, "token_x": tx, "token_y": ty, "raw_contracts": pc, "details": det}
        out["pairs"].append(rec)
        print(f"[{i}] {tx} / {ty}")
        print(json.dumps(det.get("decoded"), indent=2, default=str))
    with open(os.path.join(EVID, "pairs.json"), "w") as f:
        json.dump(out, f, indent=2)

if __name__ == "__main__":
    main()
