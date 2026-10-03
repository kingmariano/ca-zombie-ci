#!/usr/bin/env python3
"""Read actual token balances of Polynomial vaults on Optimism."""
import json, subprocess

RPC = "https://optimism-rpc.publicnode.com"

VAULTS = {
    # V2
    "V2 CallSellingVault(sETH)": "0x2D46292cbB3C601c6e2c74C32df3A4FCe99b59C7",
    "V2 PutSellingVault(sETH)": "0xb28Df1b71a5b3a638eCeDf484E0545465a45d2Ec",
    "V2 CallSellingQuoteVault": "0xB7b4270cFD938F4F1C111ac819e7365E8Ce0300a",
    "V2 GammaVault": "0x965e460bF5cb38BadA79fB2293c6304C799D0b1c",
    # V1
    "V1 sETH CoveredCall": "0x331Cf6E3E59B18a8bc776A0F652aF9E2b42781c5",
    "V1 sETH CoveredPut": "0xFa923AA6b4DF5bea456DF37FA044B37F0FDDCdb4",
    "V1 sBTC CoveredCall": "0xea48dD74BA1Ff41B705ba5Cf993B2D558e12D860",
    "V1 sBTC CoveredPut": "0x23CB080dd0ECCdacbEB0BEb2a769215280B5087D",
}

def call(to, sig, *args):
    cmd = ["cast", "call", to, sig] + list(args) + ["--rpc-url", RPC]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=45)
        if out.returncode != 0:
            return f"ERR:{out.stderr.strip().splitlines()[-1][:70]}"
        return out.stdout.strip()
    except Exception as e:
        return f"ERR:{e}"

TOKENS = {
    "sETH": "0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49",
    "sUSD": "0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9",
    "sBTC": "0x298B9B95708152ff6968aafd889c6586e9169f1D",
    "USDC": "0x7F5c764cBc14f9669B88837ca1490cCa17c31607",
    "WETH": "0x4200000000000000000000000000000000000006",
}

res = {}
for label, v in VAULTS.items():
    e = {}
    for tname, taddr in TOKENS.items():
        e[f"bal_{tname}"] = call(taddr, "balanceOf(address)(uint256)", v)
    # decimals for the tokens the vault reports
    e["underlying"] = call(v, "UNDERLYING()(address)")
    e["susd"] = call(v, "SUSD()(address)")
    e["collateral"] = call(v, "COLLATERAL()(address)")
    res[label] = e
    print("===", label, v)
    for k, val in e.items():
        print(f"   {k:18s} {val}")

json.dump(res, open("/home/heisenberg/CA/polynomial-trade/analysis/op-vault-balances.json", "w"), indent=1)
