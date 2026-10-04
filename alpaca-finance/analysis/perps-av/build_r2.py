#!/usr/bin/env python3
"""Round 2: termination state + misc probes for all 20 vaults."""
import json

mj = json.load(open("/tmp/opencode/alpaca/mainnet.json"))
vaults = mj["DeltaNeutralVaults"]
calls = []

def C(cid, to, sig, args=(), in_types=(), out_types=None):
    calls.append({"id": cid, "to": to, "sig": sig, "args": list(args),
                  "in_types": list(in_types), "types": list(out_types) if out_types else None})

for v in vaults:
    s = v["symbol"]
    va = v["address"]
    C(f"{s}|isTerminated", va, "isTerminated()", out_types=["bool"])
    C(f"{s}|terminateExecutor", va, "terminateExecutor()", out_types=["address"])
    C(f"{s}|checker", va, "checker()", out_types=["address"])
    C(f"{s}|alpacaToken", va, "alpacaToken()", out_types=["address"])
    C(f"{s}|lastFee", va, "lastFeeCollected()", out_types=["uint256"])
    C(f"{s}|shareValue1e18", va, "shareToValue(uint256)", [10**18], ["uint256"], ["uint256"])
    C(f"{s}|isTerminated2", va, "isTerminated()", out_types=["bool"])  # dup guard
    C(f"{s}|cfg|mgmtFeePerSec", v["config"], "managementFeePerSec()", out_types=["uint256"])
    C(f"{s}|cfg|mgrTreasury", v["config"], "managementFeeTreasury()", out_types=["address"])
    C(f"{s}|cfg|wFeeTreasury", v["config"], "withdrawalFeeTreasury()", out_types=["address"])
    C(f"{s}|cfg|positionValueTolerance", v["config"], "positionValueTolerance()", out_types=["uint256"])
    # share balances of a few known holders? skip. owner present from round1

# impl bytecode fetch via eth_getCode (calls with method)
impls = sorted(set(json.load(open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/table_vaults.json"))[0]["impl"] for _ in [0]))
json.dump(calls, open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/calls_r2.json", "w"), indent=0)
print("calls:", len(calls))
