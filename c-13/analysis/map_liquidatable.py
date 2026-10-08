#!/usr/bin/env python3
"""Map positions of liquidatable accounts across all Capyfi markets."""
import json
from web3 import Web3

RPC = "https://ethereum-rpc.publicnode.com"
COMPTROLLER = Web3.to_checksum_address("0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA")
ACCOUNTS = [
    "0x1E1C8A2bdA1EE312a373F9ced6d1037aA1E5918F",
    "0x492d255234C83F2ddc5aa904D8A9Db6743E9F046",
    "0x7CcA923387A3ce8d1f36354F8385aA9045798D51",
    "0xCED20c61a72d6eD57eCa5AFBcaff6F9a5D1E9E77",
    "0xbBBC3b74aD26Cfc6DE7fd18d0114cd5f58aaA49d",
]
w3 = Web3(Web3.HTTPProvider(RPC))
ct_abi = [{"name":"getAllMarkets","outputs":[{"type":"address[]"}],"inputs":[],"stateMutability":"view","type":"function"},
          {"name":"getAccountLiquidity","outputs":[{"type":"uint256"},{"type":"uint256"},{"type":"uint256"}],"inputs":[{"name":"account","type":"address"}],"stateMutability":"view","type":"function"},
          {"name":"markets","outputs":[{"name":"isListed","type":"bool"},{"name":"collateralFactorMantissa","type":"uint256"},{"name":"isComped","type":"bool"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
          {"name":"getUnderlyingPrice","outputs":[{"type":"uint256"}],"inputs":[{"name":"cToken","type":"address"}],"stateMutability":"view","type":"function"},
          {"name":"oracle","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"}]
ct = w3.eth.contract(address=COMPTROLLER, abi=ct_abi)
mk_abi = [{"name":"symbol","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
          {"name":"getAccountSnapshot","outputs":[{"type":"uint256"},{"type":"uint256"},{"type":"uint256"},{"type":"uint256"}],"inputs":[{"name":"account","type":"address"}],"stateMutability":"view","type":"function"}]
oracle = w3.eth.contract(address=ct.functions.oracle().call(), abi=[{"name":"getUnderlyingPrice","outputs":[{"type":"uint256"}],"inputs":[{"name":"cToken","type":"address"}],"stateMutability":"view","type":"function"}])
mkts = ct.functions.getAllMarkets().call()
res = {}
for a in ACCOUNTS:
    a = Web3.to_checksum_address(a)
    err, liq, short = ct.functions.getAccountLiquidity(a).call()
    entry = {"account": a, "liquidity": str(liq), "shortfall": str(short), "positions": []}
    for m in mkts:
        mkt = w3.eth.contract(address=m, abi=mk_abi)
        try:
            sym = mkt.functions.symbol().call()
        except Exception:
            sym = m
        e, ctb, borrow, er = mkt.functions.getAccountSnapshot(a).call()
        if ctb > 0 or borrow > 0:
            price = oracle.functions.getUnderlyingPrice(m).call()
            cf = ct.functions.markets(m).call()[1]
            # value USD = balance * exchangeRate / 1e18 * price / 1e18
            coll_usd = ctb * er * price / 10**36
            debt_usd = borrow * price / 10**18
            entry["positions"].append({"market": m, "symbol": sym, "cTokenBal": str(ctb),
                                       "borrowBal": str(borrow), "exchangeRate": str(er),
                                       "price1e18": str(price), "cf": str(cf),
                                       "collateral_usd": round(coll_usd, 2), "debt_usd": round(debt_usd, 2)})
    res[a] = entry
print(json.dumps(res, indent=1))
open("/home/heisenberg/CA/c-13/analysis/liquidatable_positions.json", "w").write(json.dumps(res, indent=1))
