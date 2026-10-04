#!/usr/bin/env python3
"""Build batched call list for DeltaNeutralVaults live-state snapshot.
Each call: {"id","to","sig","args":[...],"in_types":[...],"types":[out types]} OR {"id","to","slot":...}
"""
import json

MJ = "/tmp/opencode/alpaca/mainnet.json"
mj = json.load(open(MJ))
vaults = mj["DeltaNeutralVaults"]
calls = []

def C(cid, to, sig, args=(), in_types=(), out_types=None, block="latest"):
    calls.append({"id": cid, "to": to, "sig": sig, "args": list(args),
                  "in_types": list(in_types), "types": list(out_types) if out_types else None, "block": block})

def S(cid, to, slot):
    calls.append({"id": cid, "to": to, "slot": slot, "types": ["uint256"]})

# EIP-1967 slots
IMPL = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"
BEACON = "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"

for v in vaults:
    s = v["symbol"]
    S(f"{s}|impl", v["address"], IMPL)
    S(f"{s}|admin", v["address"], ADMIN)
    S(f"{s}|beacon", v["address"], BEACON)
    va = v["address"]
    C(f"{s}|totalSupply", va, "totalSupply()", out_types=["uint256"])
    C(f"{s}|totalEquityValue", va, "totalEquityValue()", out_types=["uint256"])
    C(f"{s}|positionInfo", va, "positionInfo()", out_types=["uint256"]*6)
    C(f"{s}|pendingFee", va, "pendingManagementFee()", out_types=["uint256"])
    C(f"{s}|stablePosId", va, "stableVaultPosId()", out_types=["uint256"])
    C(f"{s}|assetPosId", va, "assetVaultPosId()", out_types=["uint256"])
    C(f"{s}|owner", va, "owner()", out_types=["address"])
    C(f"{s}|config", va, "config()", out_types=["address"])
    C(f"{s}|stableToken", va, "stableToken()", out_types=["address"])
    C(f"{s}|assetToken", va, "assetToken()", out_types=["address"])
    C(f"{s}|stableVault", va, "stableVault()", out_types=["address"])
    C(f"{s}|assetVault", va, "assetVault()", out_types=["address"])
    C(f"{s}|stableWorker", va, "stableVaultWorker()", out_types=["address"])
    C(f"{s}|assetWorker", va, "assetVaultWorker()", out_types=["address"])
    C(f"{s}|priceOracle", va, "priceOracle()", out_types=["address"])
    # vault cash balances
    C(f"{s}|balStable", v["stableToken"], "balanceOf(address)", [va], ["address"], ["uint256"])
    C(f"{s}|balAsset", v["assetToken"], "balanceOf(address)", [va], ["address"], ["uint256"])
    # workers
    for wtag, w in (("sw", v["stableDeltaWorker"]), ("aw", v["assetDeltaWorker"])):
        C(f"{s}|{wtag}|totalLp", w, "totalLpBalance()", out_types=["uint256"])
        C(f"{s}|{wtag}|vault", w, "vault()", out_types=["address"])
        C(f"{s}|{wtag}|lpToken", w, "lpToken()", out_types=["address"])
        C(f"{s}|{wtag}|balStable", v["stableToken"], "balanceOf(address)", [w], ["address"], ["uint256"])
        C(f"{s}|{wtag}|balAsset", v["assetToken"], "balanceOf(address)", [w], ["address"], ["uint256"])
    # LYF vault positions / debt
    for vtag, lv, pid in (("sv", v["stableVault"], v["stableVaultPosId"]), ("av", v["assetVault"], v["assetVaultPosId"])):
        C(f"{s}|{vtag}|token", lv, "token()", out_types=["address"])
        C(f"{s}|{vtag}|positions", lv, "positions(uint256)", [int(pid)], ["uint256"], ["address", "address", "uint256"])
        C(f"{s}|{vtag}|debtShare", lv, "vaultDebtShare()", out_types=["uint256"])
        C(f"{s}|{vtag}|debtVal", lv, "vaultDebtVal()", out_types=["uint256"])
        C(f"{s}|{vtag}|pendInt0", lv, "pendingInterest(uint256)", [0], ["uint256"], ["uint256"])
    # config
    cfg = v["config"]
    C(f"{s}|cfg|withdrawalFeeBps", cfg, "withdrawalFeeBps()", out_types=["uint256"])
    C(f"{s}|cfg|depositExecutor", cfg, "depositExecutor()", out_types=["address"])
    C(f"{s}|cfg|withdrawExecutor", cfg, "withdrawExecutor()", out_types=["address"])
    C(f"{s}|cfg|controller", cfg, "controller()", out_types=["address"])
    C(f"{s}|cfg|vaultSizeAcceptable", cfg, "isVaultSizeAcceptable(uint256)", [10**30], ["uint256"], ["bool"])
    C(f"{s}|cfg|whitelistedCaller_vault", cfg, "whitelistedCallers(address)", [va], ["address"], ["bool"])
    C(f"{s}|cfg|feeExempt_vault", cfg, "feeExemptedCallers(address)", [va], ["address"], ["bool"])

# oracle prices (shared oracle)
oracle = "0x08EA5fB66EA41f236E3001d2655e43A1E735787F"
seen = set()
for v in vaults:
    s = v["symbol"]
    for ttag, tok in (("S", v["stableToken"]), ("A", v["assetToken"])):
        key = tok.lower()
        if key in seen:
            continue
        seen.add(key)
        C(f"oracle|price|{tok}", oracle, "getTokenPrice(address)", [tok], ["address"], ["uint256", "uint256"])

json.dump(calls, open("/home/heisenberg/CA/alpaca-finance/analysis/perps-av/calls_vaults.json", "w"), indent=0)
print("calls:", len(calls))
