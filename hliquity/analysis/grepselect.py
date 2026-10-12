#!/usr/bin/env python3
"""Grep contract bytecode for function selectors and address constants."""
from eth_utils import keccak
import json, re, sys

def sel(sig):
    return keccak(text=sig)[:4].hex()

CANDIDATES = [
    # SortedTroves
    "getFirst()", "getLast()", "getSize()", "getNext(address)", "getPrev(address)",
    "contains(address)", "isFull()", "getMaxSize()", "insert(address,uint256,address,address)",
    "remove(address)", "reInsert(address,uint256,address,address)",
    "findInsertPosition(uint256,address,address)", "validInsertPosition(uint256,address,address)",
    # TroveManager key funcs
    "redeemCollateral(uint256,address,address,address,uint256,uint256,uint256)",
    "liquidate(address)", "liquidateTroves(uint256)", "batchLiquidateTroves(address[])",
    "getRedemptionRate()", "getRedemptionRateWithDecay()", "getRedemptionFeeWithDecay(uint256)",
    "getTroveStatus(address)", "getTroveStake(address)", "getPendingHCHFReward(address)",
    "getPendingHBARReward(address)", "getTroveRewardSnapshots(address)", "hasPendingRewards(address)",
    "getEntireDebtAndColl(address)", "getBorrowingRate()", "getBorrowingFee(uint256)",
    # BorrowerOperations
    "openTrove(uint256,uint256,address,address)", "closeTrove()", "adjustTrove(uint256,uint256,bool,address,address)",
    "addColl()", "withdrawColl(uint256)", "withdrawHCHF(uint256)", "repayHCHF(uint256)",
    "claimCollateral()", "getCompositeDebt(uint256)",
    # StabilityPool
    "provideToSP(uint256,address)", "withdrawFromSP(uint256)", "withdrawFromSP(uint256,address)",
    "offset(uint256,uint256)", "getETH()", "getTotalHCHFDeposits()", "getDepositorHCHFGain(address)",
    "getDepositorHBARGain(address)", "getDepositorHLQTGain(address)", "getCompoundedHCHFDeposit(address)",
    "getCompoundedFrontEndStake(address)", "getTotalHCHFGains()", "getTotalHLQTGains()",
    "increaseHCHFGain(uint256,uint256)", "increaseHLQTGain(uint256,uint256)",
    # ActivePool / DefaultPool
    "getHBAR()", "getHCHFDebt()", "getETH()", "getLUSDDebt()",
    # PriceFeed
    "fetchPrice()", "lastGoodPrice()", "oracle()", "setOracle(address)", "updatePrice()",
    # Staking
    "stake(uint256)", "unstake(uint256)", "getPendingHBARGain(address)", "getPendingHLQTGain(address)",
    "totalHLQTStaked()", "totalLQTYStaked()", "F_HBAR()", "F_HLQT()", "F_ETH()", "F_LQTY()",
    # HCHF token
    "mint(address,uint256)", "burn(address,uint256)", "sendToPool(address,address,uint256)",
    "returnFromPool(address,address,uint256)", "troveManagerAddress()", "stabilityPoolAddress()",
    "borrowerOperationsAddress()", "getDeploymentStartTime()",
    # misc
    "owner()", "setAddresses(address,address,address,address,address,address,address,address,address)",
    "initialize()", "getCollateral()", "claimColl()", "name()", "symbol()", "decimals()", "totalSupply()",
]

def main():
    targets = json.load(open(sys.argv[1])) if len(sys.argv) > 1 else {}
    # targets: {name: "0xcode..."} or {name: file}
    for name, src in targets.items():
        code = open(src).read().strip() if not src.startswith("0x") else src
        hexs = code[2:] if code.startswith("0x") else code
        found = []
        for sig in CANDIDATES:
            s = sel(sig)
            n = len(re.findall(s, hexs))
            if n:
                found.append((s, sig, n))
        print(f"== {name}: {len(found)} selectors found")
        for s, sig, n in sorted(found):
            print(f"   {s} {sig} x{n}")
        # address-like constants: 40-hex chunks that are not all zero and not obviously padding
        consts = set()
        for m in re.finditer(r'[0-9a-f]{40}', hexs):
            c = m.group(0)
            if c.startswith("000000000000000000000000") and c[24:] != "0"*16:
                consts.add("0x" + c)
        print(f"   address constants:")
        for c in sorted(consts):
            print("     ", c)

if __name__ == "__main__":
    main()
