#!/usr/bin/env python3
"""Build the fund list from the enumeration files and emit unique coin types."""
import json, glob, sys

FILES = {
    "rf_type1.jsonl": ("incentive_v3_RewardFund", "A:0x81c408"),
    "rf_type2.jsonl": ("incentive_v3_RewardFund", "B:0xacc64a"),
    "rf_type3.jsonl": ("incentive_v2_IncentiveFundsPool", "A:0xe66f07"),
    "rf_type3b.jsonl": ("incentive_v2_IncentiveFundsPool", "B:0xa49c5d1c"),
}

funds = []
for fname, (kind, lineage) in FILES.items():
    with open(fname) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            resp = json.loads(line)
            for n in resp["data"]["objects"]["nodes"]:
                mv = n["asMoveObject"]["contents"]
                j = mv["json"]
                funds.append({
                    "address": n["address"],
                    "version": str(n["version"]),
                    "type_repr": mv["type"]["repr"],
                    "kind": kind,
                    "lineage": lineage,
                    "coin_type": j["coin_type"],
                    "raw_balance": j["balance"],
                })

# dedupe by address
seen = {}
for f in funds:
    seen[f["address"]] = f
funds = list(seen.values())

ctypes = sorted({f["coin_type"] for f in funds})
print(f"funds={len(funds)} unique_coin_types={len(ctypes)}", file=sys.stderr)
json.dump(funds, open("funds_merged.json", "w"), indent=1)
json.dump(ctypes, open("coin_types.json", "w"), indent=1)
for c in ctypes:
    print(c)
