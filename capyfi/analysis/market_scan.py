#!/usr/bin/env python3
"""Read-only batch market enumeration for Capyfi (Compound fork)."""
import json, sys
from web3 import Web3

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://ethereum-rpc.publicnode.com"
COMPTROLLER = Web3.to_checksum_address(sys.argv[2] if len(sys.argv) > 2 else "0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA")
w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 60}))
print("connected:", w3.is_connected(), "block:", w3.eth.block_number, file=sys.stderr)

CT_ABI = [
    {"name":"getAllMarkets","outputs":[{"type":"address[]"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"oracle","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"closeFactorMantissa","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"liquidationIncentiveMantissa","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"admin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"pendingAdmin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"pauseGuardian","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"markets","outputs":[{"name":"isListed","type":"bool"},{"name":"collateralFactorMantissa","type":"uint256"},{"name":"isComped","type":"bool"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"borrowCaps","outputs":[{"type":"uint256"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"_mintGuardianPaused","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"_borrowGuardianPaused","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"maxAssets","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"getAssetsIn","outputs":[{"type":"address[]"}],"inputs":[{"name":"account","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"getAccountLiquidity","outputs":[{"type":"uint256"},{"type":"uint256"},{"type":"uint256"}],"inputs":[{"name":"account","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"getUnderlyingPrice","outputs":[{"type":"uint256"}],"inputs":[{"name":"cToken","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"mintGuardianPaused","outputs":[{"type":"bool"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"borrowGuardianPaused","outputs":[{"type":"bool"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"transferGuardianPaused","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"seizeGuardianPaused","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"compRate","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
]
CTOKEN_ABI = [
    {"name":"symbol","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"underlying","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalSupply","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalBorrows","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalReserves","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"exchangeRateStored","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"exchangeRateCurrent","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"getCash","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"reserveFactorMantissa","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"interestRateModel","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"accrualBlockNumber","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"admin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"isCEther","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"borrowIndex","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalBorrowsCurrent","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"implementation","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"whitelist","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
]
ERC20_ABI = [
    {"name":"symbol","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"balanceOf","outputs":[{"type":"uint256"}],"inputs":[{"type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"totalSupply","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
]
ORACLE_ABI = [
    {"name":"getUnderlyingPrice","outputs":[{"type":"uint256"}],"inputs":[{"name":"cToken","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"getConfig","outputs":[{"name":"underlyingAssetDecimals","type":"uint8"},{"name":"priceFeed","type":"address"},{"name":"fixedPrice","type":"uint256"}],"inputs":[{"name":"cToken","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"owner","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"pendingOwner","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
]
WL_ABI = [
    {"name":"isActive","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"isWhitelisted","outputs":[{"type":"bool"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"owner","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
]
AGG_ABI = [
    {"name":"latestRoundData","outputs":[{"name":"roundId","type":"uint80"},{"name":"answer","type":"int256"},{"name":"startedAt","type":"uint256"},{"name":"updatedAt","type":"uint256"},{"name":"answeredInRound","type":"uint80"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"description","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
]

ct = w3.eth.contract(address=COMPTROLLER, abi=CT_ABI)
markets = ct.functions.getAllMarkets().call()
oracle_addr = ct.functions.oracle().call()
oracle = w3.eth.contract(address=oracle_addr, abi=ORACLE_ABI)
out = {
    "chain_id": w3.eth.chain_id,
    "block": w3.eth.block_number,
    "comptroller": COMPTROLLER,
    "oracle": oracle_addr,
    "oracle_owner": None,
    "closeFactorMantissa": ct.functions.closeFactorMantissa().call(),
    "liquidationIncentiveMantissa": ct.functions.liquidationIncentiveMantissa().call(),
    "admin": ct.functions.admin().call(),
    "pendingAdmin": ct.functions.pendingAdmin().call(),
    "pauseGuardian": ct.functions.pauseGuardian().call(),
    "transferGuardianPaused": ct.functions.transferGuardianPaused().call(),
    "seizeGuardianPaused": ct.functions.seizeGuardianPaused().call(),
    "mintGuardianPaused_global": ct.functions._mintGuardianPaused().call(),
    "borrowGuardianPaused_global": ct.functions._borrowGuardianPaused().call(),
    "maxAssets": ct.functions.maxAssets().call(),
    "markets": [],
}
try: out["oracle_owner"] = oracle.functions.owner().call()
except Exception as e: out["oracle_owner"] = f"err:{e}"
for m in markets:
    c = w3.eth.contract(address=m, abi=CTOKEN_ABI)
    rec = {"market": m}
    def safe(fn, *a, default=None):
        try: return fn(*a)
        except Exception as e: return default
    rec["symbol"] = safe(c.functions.symbol().call)
    rec["decimals"] = safe(c.functions.decimals().call)
    u = safe(c.functions.underlying().call)
    rec["isCEther"] = (u is None or u == "0x0000000000000000000000000000000000000000")
    if rec["isCEther"]:
        rec["underlying"] = None
        rec["underlying_symbol"] = "ETH"
        rec["underlying_decimals"] = 18
        rec["cash"] = w3.eth.get_balance(m)
    else:
        u = Web3.to_checksum_address(u)
        rec["underlying"] = u
        e = w3.eth.contract(address=u, abi=ERC20_ABI)
        rec["underlying_symbol"] = safe(e.functions.symbol().call) or "?"
        rec["underlying_decimals"] = safe(e.functions.decimals().call, default=18)
        rec["cash"] = safe(e.functions.balanceOf(m).call)
        rec["underlying_totalSupply"] = safe(e.functions.totalSupply().call)
    rec["totalSupply"] = safe(c.functions.totalSupply().call)
    rec["totalBorrows"] = safe(c.functions.totalBorrows().call)
    rec["totalBorrowsCurrent"] = safe(c.functions.totalBorrowsCurrent().call)
    rec["totalReserves"] = safe(c.functions.totalReserves().call)
    rec["exchangeRateStored"] = safe(c.functions.exchangeRateStored().call)
    rec["exchangeRateCurrent"] = safe(c.functions.exchangeRateCurrent().call)
    rec["reserveFactorMantissa"] = safe(c.functions.reserveFactorMantissa().call)
    rec["interestRateModel"] = safe(c.functions.interestRateModel().call)
    rec["accrualBlockNumber"] = safe(c.functions.accrualBlockNumber().call)
    rec["admin"] = safe(c.functions.admin().call)
    rec["implementation"] = safe(c.functions.implementation().call)
    mk = ct.functions.markets(m).call()
    rec["isListed"] = mk[0]
    rec["collateralFactorMantissa"] = mk[1]
    rec["isComped"] = mk[2]
    rec["borrowCap"] = safe(ct.functions.borrowCaps(m).call)
    rec["oracle_price"] = safe(oracle.functions.getUnderlyingPrice(m).call)
    rec["mintGuardianPaused"] = safe(ct.functions.mintGuardianPaused(m).call)
    rec["borrowGuardianPaused"] = safe(ct.functions.borrowGuardianPaused(m).call)
    try:
        cfg = oracle.functions.getConfig(m).call()
        rec["oracle_config"] = {"underlyingAssetDecimals": cfg[0], "priceFeed": cfg[1], "fixedPrice": cfg[2]}
        if cfg[1] != "0x0000000000000000000000000000000000000000":
            agg = w3.eth.contract(address=Web3.to_checksum_address(cfg[1]), abi=AGG_ABI)
            rd = agg.functions.latestRoundData().call()
            rec["feed"] = {"address": cfg[1], "description": safe(agg.functions.description().call), "decimals": safe(agg.functions.decimals().call),
                           "answer": str(rd[1]), "updatedAt": rd[3], "roundId": str(rd[0])}
    except Exception as e:
        rec["oracle_config_err"] = str(e)[:150]
    try:
        wl_addr = c.functions.whitelist().call()
        rec["whitelist"] = wl_addr
        if wl_addr and wl_addr != "0x0000000000000000000000000000000000000000":
            wl = w3.eth.contract(address=Web3.to_checksum_address(wl_addr), abi=WL_ABI)
            rec["wl_active"] = wl.functions.isActive().call()
            rec["wl_owner"] = safe(wl.functions.owner().call)
            rec["wl_attacker_0xdead"] = wl.functions.isWhitelisted(Web3.to_checksum_address("0x000000000000000000000000000000000000dEaD")).call()
    except Exception as e:
        rec["whitelist_err"] = str(e)[:150]
    out["markets"].append(rec)

print(json.dumps(out, indent=1, default=str))
