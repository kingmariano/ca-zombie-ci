#!/usr/bin/env python3
"""Read-only CapyFi oracle config + feeds on Ethereum mainnet."""
import json, sys
from web3 import Web3

RPC = "https://ethereum-rpc.publicnode.com"
UNITROLLER = Web3.to_checksum_address("0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA")
ORACLE = Web3.to_checksum_address("0xfbA2712d3bbcf32c6E0178a21955b61FE1FF424A")
w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 60}))
print("connected:", w3.is_connected(), "block:", w3.eth.block_number, file=sys.stderr)

ORACLE_ABI = [
    {"name":"getUnderlyingPrice","outputs":[{"type":"uint256"}],"inputs":[{"name":"cToken","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"getConfig","outputs":[{"name":"underlyingAssetDecimals","type":"uint8"},{"name":"priceFeed","type":"address"},{"name":"fixedPrice","type":"uint256"}],"inputs":[{"name":"cToken","type":"address"}],"stateMutability":"view","type":"function"},
    {"name":"owner","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"admin","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
]
AGG_ABI = [
    {"name":"latestRoundData","outputs":[{"name":"roundId","type":"uint80"},{"name":"answer","type":"int256"},{"name":"startedAt","type":"uint256"},{"name":"updatedAt","type":"uint256"},{"name":"answeredInRound","type":"uint80"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"decimals","outputs":[{"type":"uint8"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"description","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"owner","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"getRoundData","outputs":[{"name":"roundId","type":"uint80"},{"name":"answer","type":"int256"},{"name":"startedAt","type":"uint256"},{"name":"updatedAt","type":"uint256"},{"name":"answeredInRound","type":"uint80"}],"inputs":[{"name":"_roundId","type":"uint80"}],"stateMutability":"view","type":"function"},
]
# probe some CapyFiAggregatorV3-ish functions
PROBE = ["updater()","updaters(address)","latestAnswer()","latestTimestamp()","version()","getPrice(address)"]

CTOKENS = {
    "caLAC": "0x0568F6cb5A0E84FACa107D02f81ddEB1803f3B50",
    "caRPC": "0xF61159B4a0EE5b1615c9Afb3dA38111043344c32",
    "caUSDC": "0xc3aD34De18B59A24BD0877e454Fb924181F09C8f",
}
oracle = w3.eth.contract(address=ORACLE, abi=ORACLE_ABI)
out = {"oracle": ORACLE, "block": w3.eth.block_number, "oracle_owner": None, "markets": {}}
for f in ("owner","admin"):
    try:
        out["oracle_owner" if f=="owner" else "oracle_admin"] = getattr(oracle.functions, f)().call()
    except Exception as e:
        out[f+"_err"] = str(e)[:100]
for sym, addr in CTOKENS.items():
    c = Web3.to_checksum_address(addr)
    rec = {}
    try:
        rec["getUnderlyingPrice"] = str(oracle.functions.getUnderlyingPrice(c).call())
    except Exception as e:
        rec["price_err"] = str(e)[:100]
    try:
        cfg = oracle.functions.getConfig(c).call()
        rec["config"] = {"underlyingDecimals": cfg[0], "priceFeed": cfg[1], "fixedPrice": str(cfg[2])}
        if cfg[1] != "0x0000000000000000000000000000000000000000":
            feed = w3.eth.contract(address=Web3.to_checksum_address(cfg[1]), abi=AGG_ABI)
            fr = {"address": cfg[1]}
            for fn in ("description","decimals","latestRoundData","owner"):
                try:
                    v = getattr(feed.functions, fn)().call()
                    fr[fn] = str(v)
                except Exception as e:
                    fr[fn+"_err"] = str(e)[:80]
            # probe extended functions
            for sig in PROBE:
                try:
                    sel = w3.keccak(text=sig)[:4]
                    res = w3.eth.call({"to": Web3.to_checksum_address(cfg[1]), "data": sel})
                    fr["probe_"+sig] = res.hex()[:100]
                except Exception as e:
                    pass
            rec["feed"] = fr
    except Exception as e:
        rec["config_err"] = str(e)[:150]
    out["markets"][sym] = rec
print(json.dumps(out, indent=1, default=str))
