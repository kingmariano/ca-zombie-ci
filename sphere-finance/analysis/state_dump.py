#!/usr/bin/env python3
"""Comprehensive live-state dump of Sphere contracts at latest block."""
import sys, json
sys.path.insert(0, '/home/heisenberg/CA/sphere-finance/analysis')
from rpc import batch, block_number

BLK = block_number()
def b(calls):
    out = []
    for i in range(0, len(calls), 10):
        out += batch(calls[i:i+10])
        print(f"  batch {i//10+1}/{(len(calls)+9)//10}", flush=True)
    return out

# selector helpers
def sel(sig):
    import hashlib
    return "0x" + hashlib.sha3_256(sig.encode()).hexdigest()[:8] if False else None

from eth_utils import keccak
def S(sig): return "0x" + keccak(text=sig)[:4].hex()

def enc_addr(a): return a[2:].lower().rjust(64, "0")

CONTRACTS = {
  "SPHERE_TUP": "0x62f594339830b90ae4c084ae7d223ffafd9658a7",
  "SPHERE_impl_old": "0x82cf03485bd0cfee315be1e7a9c49f28106f271b",
  "ProxyAdmin": "0xf27522d4a48b9a5fe53f69e343b15926b540f0ab",
  "Settings_TUP": "0xc49be67aaa0a2476e5132ad77216521971643857",
  "Settings_impl": "0x92883e8aef7db8228a55428132b867f8686cd883",
  "Timelock": "0xa0dccb94bc35576ab9820c2dda9d6fc0042d6d72",
  "BondTreasurySwapper": "0xb61bd49a1c5258a3ca00a9a7b4df823cbf057891",
  "OvernightStrategy": "0x2d980268f7a3366f6fa0c36982c597359e358615",
  "BondDepo": "0xd7dc984cf5f799d5af4e3a56c2635e5379623fd6",
  "Treasury1_Safe": "0x1a2ce410a034424b784d4b228f167a061b94cff4",
  "Treasury2_Safe": "0x826b8d2d523e7af40888754e3de64348c00b99f4",
  "Treasury3_InvSafe": "0x20d61737f972eecb0af5f0a85ab358cd083dd56a",
  "SPHERE_v1": "0x8d546026012bf75073d8a586f24a5d5ff75b9716",
  "FairLaunch1": "0x1712412a7c4556bfb5ffee753b112960df6348f3",
  "SphereTreasury": "0xc747db6ebd5dfc93c7d2f4af208a9618beec46a3",
  "wSPHERE": "0x991b73fb44a6b618efbf3403924c09530ee4d5dc",
  "SphereZap": "0x5c8803c06aa6e4ba2a26c890d022a7a2f3b2889d",
  "SphereFairLaunch": "0x7e96bbeb1c13978f7fe5c50ae1e332148bb14277",
  "CompensationLaunchPool": "0xfe28da33c260023356d3c5d2fe86134811d2ab2f",
}

# EIP-1967 slots
IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"

calls = []
meta = []
# storage slots
for name in ["SPHERE_TUP", "Settings_TUP"]:
    a = CONTRACTS[name]
    calls.append(("eth_getStorageAt", [a, IMPL_SLOT, hex(BLK)])); meta.append((name, "impl_slot"))
    calls.append(("eth_getStorageAt", [a, ADMIN_SLOT, hex(BLK)])); meta.append((name, "admin_slot"))

# generic getters
GETTERS = {
  "owner()": S("owner()"),
  "admin()": S("admin()"),
  "implementation()": S("implementation()"),
  "settings()": S("settings()"),
  "totalSupply()": S("totalSupply()"),
  "rewardToken()": S("rewardToken()"),
  "principle()": S("principle()"),
  "treasury()": S("treasury()"),
  "strategyAddress()": S("strategyAddress()"),
  "availableDebt()": S("availableDebt()"),
  "totalDebt()": S("totalDebt()"),
  "lastDecay()": S("lastDecay()"),
  "lpBonded()": S("lpBonded()"),
  "tokenVested()": S("tokenVested()"),
  "paidOut()": S("paidOut()"),
  "assetAddress()": S("assetAddress()"),
  "routerAddress()": S("routerAddress()"),
  "liquidityReceiver()": S("liquidityReceiver()"),
  "fundsReceiver()": S("fundsReceiver()"),
  "principleAsset()": S("principleAsset()"),
  "miscellaneousReceiver()": S("miscellaneousReceiver()"),
  "feeSplit()": S("feeSplit()"),
  "burnFees()": S("burnFees()"),
  "liquidityFees()": S("liquidityFees()"),
  "getMinDelay()": S("getMinDelay()"),
  "initialDistributionFinished()": S("initialDistributionFinished()"),
  "swapEnabled()": S("swapEnabled()"),
  "autoRebase()": S("autoRebase()"),
  "nextRebase()": S("nextRebase()"),
  "rebaseEpoch()": S("rebaseEpoch()"),
  "gonsPerFragment()": S("gonsPerFragment()"),
  "rewardYield()": S("rewardYield()"),
  "rewardYieldDenominator()": S("rewardYieldDenominator()"),
  "isWall()": S("isWall()"),
  "partyTime()": S("partyTime()"),
  "goDeflationary()": S("goDeflationary()"),
  "getThreshold()": S("getThreshold()"),
  "getOwners()": S("getOwners()"),
}
for name in ["SPHERE_TUP", "SPHERE_impl_old", "ProxyAdmin", "Settings_TUP", "Settings_impl",
             "Timelock", "BondTreasurySwapper", "OvernightStrategy", "BondDepo",
             "SPHERE_v1", "SphereTreasury", "wSPHERE", "SphereZap"]:
    a = CONTRACTS[name]
    for g, data in GETTERS.items():
        calls.append(("eth_call", [{"to": a, "data": data}, hex(BLK)]))
        meta.append((name, g))
for name in ["Treasury1_Safe", "Treasury2_Safe", "Treasury3_InvSafe"]:
    a = CONTRACTS[name]
    for g in ["getThreshold()", "getOwners()"]:
        calls.append(("eth_call", [{"to": a, "data": GETTERS[g]}, hex(BLK)]))
        meta.append((name, g))

res = b(calls)
out = {"block": BLK, "contracts": CONTRACTS, "values": {}}
for (name, g), r in zip(meta, res):
    key = f"{name}.{g}"
    if r is None:
        out["values"][key] = None
    elif g.endswith("_slot"):
        out["values"][key] = "0x" + r[-40:]
    else:
        out["values"][key] = r
    print(key, "=", out["values"][key], flush=True)

json.dump(out, open("/home/heisenberg/CA/sphere-finance/analysis/state_dump.json", "w"), indent=1)
print("block", BLK)
