#!/usr/bin/env python3
"""Stage 4: native HYPE balances of pools / gauges / fees vaults / core contracts at BLOCK."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/hyperevm-residuals/analysis")
from hl_rpc import *

BASE = "/home/heisenberg/CA/hyperevm-residuals/analysis"
BLOCK = 47620218
B = hex(BLOCK)
ZERO = "0x0000000000000000000000000000000000000000"


def main():
    raw = json.load(open(f"{BASE}/nest_value_raw.json"))
    pools = [r["pool"] for r in raw["pool_rows"]]
    gauges = [g for g in raw["gauges_map"]]
    vaults = [v for v in raw["vaults_map"]]
    core = ["0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074", "0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901",
            "0x574f6865140e6929bDed24596D78a8D9c07E356d", "0x15E408A37cE4D13218202C0054B0f485E38F5768",
            "0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3", "0xEAF58788a405F3253814B4559391a22bE8616250",
            "0x843d31e601b38F7207864457f0fB38E14441E792"]
    calls, meta = [], []
    for label, arr in (("pool", pools), ("gauge", gauges), ("vault", vaults), ("core", core)):
        for a in arr:
            calls.append(("eth_getBalance", [a, B])); meta.append((label, a))
    out = {}
    cm = list(zip(calls, meta))
    for i in range(0, len(cm), 20):
        res = batch([c for c, _ in cm[i:i + 20]], chunk=20)
        for (c, m), r in zip(cm[i:i + 20], res):
            kind, a = m
            out.setdefault(kind, {})[a] = int(r, 16) if r else 0
    json.dump({"block": BLOCK, "native": out}, open(f"{BASE}/nest_native.json", "w"), indent=1)
    nz = {k: {a: v for a, v in d.items() if v} for k, d in out.items()}
    print("nonzero native balances:")
    for k, d in nz.items():
        for a, v in d.items():
            print(f"  {k} {a} {v/1e18:.6f} HYPE")


if __name__ == "__main__":
    main()
