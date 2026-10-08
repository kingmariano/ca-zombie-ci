#!/usr/bin/env python3
"""Read-only batch market enumeration for CapyFi (Compound fork) on World Chain (480).
Pins a block and dumps JSON to stdout."""
import json, sys
from web3 import Web3

RPC = sys.argv[1] if len(sys.argv) > 1 else "https://worldchain-mainnet.g.alchemy.com/public"
BLK = int(sys.argv[2]) if len(sys.argv) > 2 else 36074434
COMPTROLLER = Web3.to_checksum_address("0x589d63300976759a0fc74ea6fA7D951f581252D7")
w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 60}))
print("connected:", w3.is_connected(), "chain:", w3.eth.chain_id, "head:", w3.eth.block_number, "pin:", BLK, file=sys.stderr)

CT_ABI = [
    {"name":"getAllMarkets","outputs":[{"type":"address[]"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"oracle","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"closeFactorMantissa","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"liquidationIncentiveMantissa","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"admin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"pendingAdmin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"comptrollerImplementation","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"pendingComptrollerImplementation","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"pauseGuardian","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"borrowCapGuardian","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
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
    {"name":"getCompAddress","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
]
CTOKEN_ABI = [
    {"name":"symbol","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"name","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"underlying","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalSupply","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalBorrows","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalReserves","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"exchangeRateStored","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"exchangeRateCurrent","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"getCash","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"reserveFactorMantissa","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"protocolSeizeShareMantissa","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"interestRateModel","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"accrualBlockNumber","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"admin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"pendingAdmin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"isCToken","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"comptroller","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"borrowIndex","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"totalBorrowsCurrent","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"implementation","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"whitelist","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
]
ERC20_ABI = [
    {"name":"symbol","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"balanceOf","outputs":[{"type":"uint256"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
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
    {"name":"admin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
]
AGG_ABI = [
    {"name":"latestRoundData","outputs":[{"name":"roundId","type":"uint80"},{"name":"answer","type":"int256"},{"name":"startedAt","type":"uint256"},{"name":"updatedAt","type":"uint256"},{"name":"answeredInRound","type":"uint80"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"description","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
]

def safe(fn, *a, default=None, **kw):
    try:
        return fn(*a, **kw)
    except Exception as e:
        return default

ct = w3.eth.contract(address=COMPTROLLER, abi=CT_ABI)
markets = ct.functions.getAllMarkets().call(block_identifier=BLK)
oracle_addr = ct.functions.oracle().call(block_identifier=BLK)
oracle = w3.eth.contract(address=oracle_addr, abi=ORACLE_ABI)
out = {
    "chain_id": w3.eth.chain_id,
    "block": BLK,
    "comptroller": COMPTROLLER,
    "oracle": oracle_addr,
    "oracle_owner": safe(oracle.functions.owner().call, block_identifier=BLK),
    "comptrollerImplementation": ct.functions.comptrollerImplementation().call(block_identifier=BLK),
    "pendingComptrollerImplementation": safe(ct.functions.pendingComptrollerImplementation().call, block_identifier=BLK),
    "closeFactorMantissa": ct.functions.closeFactorMantissa().call(block_identifier=BLK),
    "liquidationIncentiveMantissa": ct.functions.liquidationIncentiveMantissa().call(block_identifier=BLK),
    "admin": ct.functions.admin().call(block_identifier=BLK),
    "pendingAdmin": ct.functions.pendingAdmin().call(block_identifier=BLK),
    "pauseGuardian": ct.functions.pauseGuardian().call(block_identifier=BLK),
    "borrowCapGuardian": safe(ct.functions.borrowCapGuardian().call, block_identifier=BLK),
    "transferGuardianPaused": ct.functions.transferGuardianPaused().call(block_identifier=BLK),
    "seizeGuardianPaused": ct.functions.seizeGuardianPaused().call(block_identifier=BLK),
    "mintGuardianPaused_global": ct.functions._mintGuardianPaused().call(block_identifier=BLK),
    "borrowGuardianPaused_global": ct.functions._borrowGuardianPaused().call(block_identifier=BLK),
    "maxAssets": ct.functions.maxAssets().call(block_identifier=BLK),
    "compRate": safe(ct.functions.compRate().call, block_identifier=BLK),
    "getCompAddress": safe(ct.functions.getCompAddress().call, block_identifier=BLK),
    "markets": [],
}
for m in markets:
    c = w3.eth.contract(address=m, abi=CTOKEN_ABI)
    rec = {"market": m}
    rec["symbol"] = safe(c.functions.symbol().call, block_identifier=BLK)
    rec["name"] = safe(c.functions.name().call, block_identifier=BLK)
    rec["decimals"] = safe(c.functions.decimals().call, block_identifier=BLK)
    rec["isCToken"] = safe(c.functions.isCToken().call, block_identifier=BLK)
    rec["comptroller_of_market"] = safe(c.functions.comptroller().call, block_identifier=BLK)
    u = safe(c.functions.underlying().call, block_identifier=BLK)
    rec["isCEther"] = (u is None or u == "0x0000000000000000000000000000000000000000")
    if rec["isCEther"]:
        rec["underlying"] = None
        rec["underlying_symbol"] = "ETH"
        rec["underlying_decimals"] = 18
        rec["cash"] = w3.eth.get_balance(m, block_identifier=BLK)
    else:
        u = Web3.to_checksum_address(u)
        rec["underlying"] = u
        e = w3.eth.contract(address=u, abi=ERC20_ABI)
        rec["underlying_symbol"] = safe(e.functions.symbol().call, block_identifier=BLK) or "?"
        rec["underlying_decimals"] = safe(e.functions.decimals().call, block_identifier=BLK, default=18)
        rec["cash"] = safe(e.functions.balanceOf(m).call, block_identifier=BLK)
        rec["underlying_totalSupply"] = safe(e.functions.totalSupply().call, block_identifier=BLK)
    rec["totalSupply"] = safe(c.functions.totalSupply().call, block_identifier=BLK)
    rec["totalBorrows"] = safe(c.functions.totalBorrows().call, block_identifier=BLK)
    rec["totalBorrowsCurrent"] = safe(c.functions.totalBorrowsCurrent().call, block_identifier=BLK)
    rec["totalReserves"] = safe(c.functions.totalReserves().call, block_identifier=BLK)
    rec["exchangeRateStored"] = safe(c.functions.exchangeRateStored().call, block_identifier=BLK)
    rec["exchangeRateCurrent"] = safe(c.functions.exchangeRateCurrent().call, block_identifier=BLK)
    rec["reserveFactorMantissa"] = safe(c.functions.reserveFactorMantissa().call, block_identifier=BLK)
    rec["protocolSeizeShareMantissa"] = safe(c.functions.protocolSeizeShareMantissa().call, block_identifier=BLK)
    rec["interestRateModel"] = safe(c.functions.interestRateModel().call, block_identifier=BLK)
    rec["accrualBlockNumber"] = safe(c.functions.accrualBlockNumber().call, block_identifier=BLK)
    rec["borrowIndex"] = safe(c.functions.borrowIndex().call, block_identifier=BLK)
    rec["admin"] = safe(c.functions.admin().call, block_identifier=BLK)
    rec["pendingAdmin"] = safe(c.functions.pendingAdmin().call, block_identifier=BLK)
    rec["implementation"] = safe(c.functions.implementation().call, block_identifier=BLK)
    mk = ct.functions.markets(m).call(block_identifier=BLK)
    rec["isListed"] = mk[0]
    rec["collateralFactorMantissa"] = mk[1]
    rec["isComped"] = mk[2]
    rec["borrowCap"] = safe(ct.functions.borrowCaps(m).call, block_identifier=BLK)
    rec["oracle_price"] = safe(oracle.functions.getUnderlyingPrice(m).call, block_identifier=BLK)
    rec["mintGuardianPaused"] = safe(ct.functions.mintGuardianPaused(m).call, block_identifier=BLK)
    rec["borrowGuardianPaused"] = safe(ct.functions.borrowGuardianPaused(m).call, block_identifier=BLK)
    try:
        cfg = oracle.functions.getConfig(m).call(block_identifier=BLK)
        rec["oracle_config"] = {"underlyingAssetDecimals": cfg[0], "priceFeed": cfg[1], "fixedPrice": str(cfg[2])}
        if cfg[1] != "0x0000000000000000000000000000000000000000":
            agg = w3.eth.contract(address=Web3.to_checksum_address(cfg[1]), abi=AGG_ABI)
            rd = agg.functions.latestRoundData().call(block_identifier=BLK)
            rec["feed"] = {"address": cfg[1], "description": safe(agg.functions.description().call, block_identifier=BLK), "decimals": safe(agg.functions.decimals().call, block_identifier=BLK),
                           "answer": str(rd[1]), "updatedAt": rd[3], "roundId": str(rd[0]),
                           "feed_code_len": len(w3.eth.get_code(Web3.to_checksum_address(cfg[1]), block_identifier=BLK).hex())}
    except Exception as e:
        rec["oracle_config_err"] = str(e)[:200]
    try:
        wl_addr = c.functions.whitelist().call(block_identifier=BLK)
        rec["whitelist"] = wl_addr
        if wl_addr and wl_addr != "0x0000000000000000000000000000000000000000":
            wl = w3.eth.contract(address=Web3.to_checksum_address(wl_addr), abi=WL_ABI)
            rec["wl_active"] = safe(wl.functions.isActive().call, block_identifier=BLK)
            rec["wl_owner"] = safe(wl.functions.owner().call, block_identifier=BLK)
            rec["wl_admin"] = safe(wl.functions.admin().call, block_identifier=BLK)
            rec["wl_attacker_0xdead"] = safe(wl.functions.isWhitelisted(Web3.to_checksum_address("0x000000000000000000000000000000000000dEaD")).call, block_identifier=BLK)
            rec["wl_zero"] = safe(wl.functions.isWhitelisted("0x0000000000000000000000000000000000000000").call, block_identifier=BLK)
    except Exception as e:
        rec["whitelist_err"] = str(e)[:200]
    out["markets"].append(rec)

print(json.dumps(out, indent=1, default=str))
