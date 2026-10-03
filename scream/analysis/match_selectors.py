#!/usr/bin/env python3
"""Match extracted selectors against locally computed known function signatures."""
import json, subprocess

sel = json.load(open("/home/heisenberg/CA/scream/analysis/selectors.json"))

known = {
    # Comptroller / Unitroller
    "mintAllowed(address,address,uint256)": None,
    "redeemAllowed(address,address,uint256)": None,
    "borrowAllowed(address,address,uint256)": None,
    "repayBorrowAllowed(address,address,uint256)": None,
    "liquidateBorrowAllowed(address,address,address,uint256,address)": None,
    "seizeAllowed(address,address,address,uint256)": None,
    "transferAllowed(address,address,address,uint256)": None,
    "liquidateCalculateSeizeTokens(address,address,uint256)": None,
    "getAssetsIn(address)": None,
    "checkMembership(address,address)": None,
    "enterMarkets(address[])": None,
    "exitMarket(address)": None,
    "getAccountLiquidity(address)": None,
    "getHypotheticalAccountLiquidity(address,address,uint256,uint256)": None,
    "mintGuardianPaused(address)": None,
    "borrowGuardianPaused(address)": None,
    "transferGuardianPaused()": None,
    "seizeGuardianPaused()": None,
    "pauseGuardian()": None,
    "closeFactorMantissa()": None,
    "liquidationIncentiveMantissa()": None,
    "oracle()": None,
    "admin()": None,
    "pendingAdmin()": None,
    "comptrollerImplementation()": None,
    "pendingComptrollerImplementation()": None,
    "_setPendingImplementation(address)": None,
    "_acceptImplementation()": None,
    "_setPendingAdmin(address)": None,
    "_acceptAdmin()": None,
    "_setCloseFactor(uint256)": None,
    "_setCollateralFactor(address,uint256)": None,
    "_setLiquidationIncentive(uint256)": None,
    "_setPauseGuardian(address)": None,
    "_setMintPaused(address,bool)": None,
    "_setBorrowPaused(address,bool)": None,
    "_setTransferPaused(bool)": None,
    "_setSeizePaused(bool)": None,
    "_setPriceOracle(address)": None,
    "_supportMarket(address)": None,
    "_setBorrowCap(address,uint256)": None,
    "borrowCaps(address)": None,
    "markets(address)": None,
    "getAllMarkets()": None,
    "claimComp(address)": None,
    "claimComp(address,address[])": None,
    "compAccrued(address)": None,
    "compSupplySpeeds(address)": None,
    "compBorrowSpeeds(address)": None,
    "compRate()": None,
    "refreshCompSpeeds()": None,
    "_setCompSpeed(address,uint256)": None,
    "_setContributorCompSpeed(address,uint256)": None,
    "updateContributorRewards(address)": None,
    "getCompAddress()": None,
    # CToken
    "mint(uint256)": None,
    "mint(uint256,address)": None,
    "redeem(uint256)": None,
    "redeemUnderlying(uint256)": None,
    "borrow(uint256)": None,
    "repayBorrow(uint256)": None,
    "repayBorrowBehalf(address,uint256)": None,
    "liquidateBorrow(address,uint256,address)": None,
    "seize(address,address,uint256)": None,
    "accrueInterest()": None,
    "exchangeRateCurrent()": None,
    "exchangeRateStored()": None,
    "getCash()": None,
    "borrowBalanceCurrent(address)": None,
    "borrowBalanceStored(address)": None,
    "balanceOf(address)": None,
    "balanceOfUnderlying(address)": None,
    "transfer(address,uint256)": None,
    "transferFrom(address,address,uint256)": None,
    "approve(address,uint256)": None,
    "allowance(address,address)": None,
    "totalSupply()": None,
    "totalBorrows()": None,
    "totalReserves()": None,
    "totalBorrowsCurrent()": None,
    "reserveFactorMantissa()": None,
    "borrowIndex()": None,
    "borrowRatePerBlock()": None,
    "supplyRatePerBlock()": None,
    "interestRateModel()": None,
    "comptroller()": None,
    "underlying()": None,
    "name()": None,
    "symbol()": None,
    "decimals()": None,
    "initialExchangeRateMantissa()": None,
    "accrualBlockNumber()": None,
    "implementation()": None,
    "_setImplementation(address,bool,bytes)": None,
    "_becomeImplementation(bytes)": None,
    "_resignImplementation()": None,
    "_setReserveFactor(uint256)": None,
    "_reduceReserves(uint256)": None,
    "_setInterestRateModel(address)": None,
    "_setPendingAdmin(address)": None,
    "_acceptAdmin()": None,
    "_addReserves(uint256)": None,
    # Oracle
    "getUnderlyingPrice(address)": None,
    "isPriceOracle()": None,
    "setUnderlyingPrice(address,uint256)": None,
    "setDirectPrice(address,uint256)": None,
    "getPrice(address)": None,
    "price(address)": None,
    "feed(address)": None,
    "feeds(address)": None,
    "aggregators(address)": None,
    "getFeed(address)": None,
    "setFeed(address,address)": None,
    "owner()": None,
    "setAdmin(address)": None,
    "pendingAdmin()": None,
    "latestAnswer()": None,
    "latestRoundData()": None,
}

sig2sel = {}
for s in known:
    try:
        out = subprocess.run(["cast", "sig", s], capture_output=True, text=True, timeout=10).stdout.strip()
        if out.startswith("0x"):
            sig2sel[out.lower()] = s
    except Exception:
        pass

for name, data in sel.items():
    print(f"\n== {name} {data['address']}")
    matched = []
    for s, t in sorted(data["selectors"].items()):
        key = s if s.startswith("0x") else "0x" + s
        if t is None and key in sig2sel:
            matched.append((key, sig2sel[key]))
    for s, t in matched:
        print(f"  {s} {t}")
    print(f"  ({len(matched)} matched / {len(data['selectors'])} extracted)")
