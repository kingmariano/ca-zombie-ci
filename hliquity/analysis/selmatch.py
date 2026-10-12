#!/usr/bin/env python3
"""Match 4-byte selectors against candidate signatures."""
from eth_utils import keccak
import json

sel_to_find = {
    # HCHF contract dispatch table
    "5a4d28bb": None, "70a08231": None, "95d89b41": None, "9b23d3d9": None,
    "9d76ea58": None, "9dc29fac": None, "b7f8cf9b": None, "bb997bac": None,
    "06fdde03": None, "40c10f19": None,
    # TroveManager interesting selectors seen
    "9f5f8e22": None, "048c661d": None, "4e443d9e": None, "2f865568": None,
    "d3d6f843": None, "f1008100": None, "cbd138ae": None,
}
candidates = []
names = [
    "troveManager()", "stabilityPool()", "borrowerOperations()", "owner()",
    "name()", "symbol()", "decimals()", "totalSupply()", "balanceOf(address)",
    "mint(address,uint256)", "burn(address,uint256)", "mintHCHF(address,uint256)",
    "burnHCHF(address,uint256)", "associate()", "associateToken(address,address)",
    "transfer(address,uint256)", "transferFrom(address,address,uint256)",
    "approve(address,uint256)", "allowance(address,address)",
    "getTroveDebt(address)", "getTroveColl(address)", "getTroveStatus(address)",
    "getCurrentICR(address,uint256)", "getNominalICR(address)",
    "getTroveOwnersCount()", "getTroveFromTroveOwnersArray(uint256)",
    "getEntireSystemColl()", "getEntireSystemDebt()", "getTCR(uint256)",
    "checkRecoveryMode(uint256)", "baseRate()", "getRedemptionRate()",
    "lastFeeOperationTime()", "totalStakes()", "getLastZombieTrove()",
    "getTotalHCHFDeposits()", "getTotalHCHFGains()", "getTotalHLQTGains()",
    "getHBAR()", "getHCHFDebt()", "getSize()", "getFirst()", "getLast()",
    "totalHLQTStaked()", "totalLQTYStaked()", "F_HBAR()", "F_HLQT()",
    "totalHBARGains()", "fetchPrice()", "lastGoodPrice()",
    "liquidate(address)", "liquidateTroves(uint256)", "batchLiquidateTroves(address[])",
    "redeemCollateral(uint256,address,address,address,uint256,uint256,uint256)",
    "setAddresses(address,address,address,address,address,address,address,address,address)",
    "initialize()", "setAddresses(address,address,address,address,address,address,address,address,address,address)",
    "mint(address,address,uint256)", "mint(address,uint256,bytes)",
    "getPendingHBARGain(address)", "getPendingHLQTGain(address)",
    "stake(uint256)", "unstake(uint256)", "getPendingETHGain(address)",
    "getPendingLQTYGain(address)", "LUSDToken()", "hchfToken()",
    "getTroveManager()", "getStabilityPool()", "getBorrowerOperations()",
    "sendToPool(address,address,uint256)", "returnFromPool(address,address,uint256)",
    "mintHCHF(address,address,uint256)", "burnHCHF(address,uint256)",
]
for n in names:
    candidates.append((keccak(text=n)[:4].hex(), n))

for s in sel_to_find:
    matches = [n for h, n in candidates if h == s]
    print(s, "->", matches if matches else "?")
