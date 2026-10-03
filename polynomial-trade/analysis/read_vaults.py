#!/usr/bin/env python3
"""Read live state of Polynomial Earn vaults on Optimism (read-only)."""
import json, subprocess, sys

RPC = "https://optimism-rpc.publicnode.com"

V2 = {
    "CallSellingVault(sETH)": "0x2D46292cbB3C601c6e2c74C32df3A4FCe99b59C7",
    "PutSellingVault(sETH)": "0xb28Df1b71a5b3a638eCeDf484E0545465a45d2Ec",
    "CallSellingQuoteVault(sUSD)": "0xB7b4270cFD938F4F1C111ac819e7365E8Ce0300a",
    "GammaVault": "0x965e460bF5cb38BadA79fB2293c6304C799D0b1c",
}
V1 = {
    "V1 sETH CoveredCall": "0x331Cf6E3E59B18a8bc776A0F652aF9E2b42781c5",
    "V1 sETH CoveredPut": "0xFa923AA6b4DF5bea456DF37FA044B37F0FDDCdb4",
    "V1 sBTC CoveredCall": "0xea48dD74BA1Ff41B705ba5Cf993B2D558e12D860",
    "V1 sBTC CoveredPut": "0x23CB080dd0ECCdacbEB0BEb2a769215280B5087D",
}

def call(to, sig):
    try:
        out = subprocess.run(
            ["cast", "call", to, sig, "--rpc-url", RPC],
            capture_output=True, text=True, timeout=45,
        )
        if out.returncode != 0:
            return f"ERR:{out.stderr.strip()[:80]}"
        return out.stdout.strip()
    except Exception as e:
        return f"ERR:{e}"

def block():
    out = subprocess.run(["cast", "block-number", "--rpc-url", RPC], capture_output=True, text=True)
    return out.stdout.strip()

# signatures to read
SIGS = [
    ("UNDERLYING", "UNDERLYING()(address)"),
    ("SUSD", "SUSD()(address)"),
    ("COLLATERAL", "COLLATERAL()(address)"),
    ("VAULT_TOKEN", "VAULT_TOKEN()(address)"),
    ("owner", "owner()(address)"),
    ("authority", "authority()(address)"),
    ("paused", "paused()(bool)"),
    ("depositsPaused", "depositsPaused()(bool)"),
    ("totalFunds", "totalFunds()(uint256)"),
    ("usedFunds", "usedFunds()(uint256)"),
    ("totalPremiumCollected", "totalPremiumCollected()(uint256)"),
    ("totalQueuedDeposits", "totalQueuedDeposits()(uint256)"),
    ("totalQueuedWithdrawals", "totalQueuedWithdrawals()(uint256)"),
    ("queuedDepositHead", "queuedDepositHead()(uint256)"),
    ("queuedWithdrawalHead", "queuedWithdrawalHead()(uint256)"),
    ("nextQueuedDepositId", "nextQueuedDepositId()(uint256)"),
    ("nextQueuedWithdrawalId", "nextQueuedWithdrawalId()(uint256)"),
    ("getTotalSupply", "getTotalSupply()(uint256)"),
    ("performanceFee", "performanceFee()(uint256)"),
    ("withdrawalFee", "withdrawalFee()(uint256)"),
]

def bal_of(token, who):
    return call(token, f"balanceOf(address)(uint256)".replace("address", who))

result = {"rpc": RPC, "block": block(), "vaults": {}}
for label, addr in {**V2, **V1}.items():
    entry = {"address": addr, "reads": {}}
    for name, sig in SIGS:
        entry["reads"][name] = call(addr, sig)
    # token balances
    und = entry["reads"]["UNDERLYING"]
    susd = entry["reads"]["SUSD"]
    coll = entry["reads"]["COLLATERAL"]
    vt = entry["reads"]["VAULT_TOKEN"]
    for tname, taddr in [("UNDERLYING", und), ("SUSD", susd), ("COLLATERAL", coll)]:
        if taddr.startswith("0x") and len(taddr) == 42:
            entry["reads"][f"bal_{tname}"] = bal_of(taddr, addr)
    if vt.startswith("0x") and len(vt) == 42:
        entry["reads"]["vaultToken_totalSupply"] = call(vt, "totalSupply()(uint256)")
        entry["reads"]["vaultToken_symbol"] = call(vt, "symbol()(string)")
        entry["reads"]["vaultToken_name"] = call(vt, "name()(string)")
    result["vaults"][label] = entry
    print(f"=== {label} {addr}")
    for k, v in entry["reads"].items():
        print(f"   {k:28s} {v}")

json.dump(result, open("/home/heisenberg/CA/polynomial-trade/analysis/op-vault-state.json", "w"), indent=1)
print("\nBLOCK:", result["block"])
