#!/usr/bin/env python3
"""Quick live vault enumeration for PoC design (Cega V1 ETH + ARB). Read-only. Uses ABI files."""
import json, subprocess, sys, os

ETH = "https://ethereum-rpc.publicnode.com"
ARB = os.environ.get("ARB_RPC_URL", "https://arb1.arbitrum.io/rpc")
BASE = os.path.dirname(os.path.abspath(__file__))
ABI_FCN = os.path.join(BASE, "sources/insanic_1.abi")
ABI_LOV = os.path.join(BASE, "sources/puppyLov_42161.abi")

PRODUCTS_ETH = {
    "supercharger": "0x042021d59731d3fFA908c7c4211177137Ba362Ea",
    "go-fast": "0x56F00A399151EC74cf7bE8DC38225363E84975E6",
    "insanic": "0x784e3C592A6231D92046bd73508B3aAe3A7cc815",
    "puppy": "0x2aAE28E495626F587677ca779838266DB9bD6Cd1",
    "l2": "0x98b872604F36807169c096241ECD4646021de133",
    "starboard": "0xAB8631417271Dbb928169F060880e289877Ff158",
    "autopilot": "0xcf81b51AecF6d88dF12Ed492b7b7f95bBc24B8Af",
    "cruise-control": "0x80ec1c0da9bfBB8229A1332D40615C5bA2AbbEA8",
    "genesis-basket": "0x94C5D3C2fE4EF2477E562EEE7CCCF07Ee273B108",
}

def cast(args, rpc, abi=None):
    cmd = ["cast", "call"] + args + ["--rpc-url", rpc]
    if abi:
        cmd += ["--abi", abi]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return r.stdout.strip() if r.returncode == 0 else f"ERR:{r.stderr.strip()[:200]}"

results = {"ethereum": {}, "arbitrum": {}}
for name, prod in PRODUCTS_ETH.items():
    arr = cast([prod, "getVaultAddresses()(address[])"], ETH)
    addrs = [a.strip() for a in arr.strip("[]").split(",")] if not arr.startswith("ERR") and arr.strip() != "[]" else []
    entry = {"product": prod, "vaults": []}
    for v in addrs:
        meta = cast([prod, "vaults(address)(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,uint8,bool)", v], ETH)
        entry["vaults"].append({"vault": v, "meta": meta})
    results["ethereum"][name] = entry
    print(f"ETH {name}: {len(addrs)} vaults")
    for x in entry["vaults"]:
        print("   ", x["vault"], "|", x["meta"].replace("\n", " ")[:260])

prod = "0x6A9201Db9222cFb5164cfb8F192903270f8a6e93"
results["arbitrum"]["puppy-lov"] = {"product": prod, "leverages": {}, "vaults": []}
for lev in range(1, 6):
    allowed = cast([prod, "leverages(uint256)(bool,bool,uint256,uint256,uint256,address[])", str(lev)], ARB)
    results["arbitrum"]["puppy-lov"]["leverages"][str(lev)] = allowed
    print(f"ARB puppy-lov lev{lev}:", allowed.replace("\n", " ")[:200])
    arr = cast([prod, "getVaultAddresses(uint256)(address[])", str(lev)], ARB)
    if arr.startswith("ERR") or arr.strip() == "[]":
        continue
    addrs = [a.strip() for a in arr.strip("[]").split(",")]
    for v in addrs:
        meta = cast([prod, "vaults(address)(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address,uint8,bool)", v], ARB)
        results["arbitrum"]["puppy-lov"]["vaults"].append({"leverage": lev, "vault": v, "meta": meta})
        print("   lev", lev, v, "|", meta.replace("\n", " ")[:260])

json.dump(results, open(os.path.join(BASE, "vaults_quick.json"), "w"), indent=1)
print("saved")
