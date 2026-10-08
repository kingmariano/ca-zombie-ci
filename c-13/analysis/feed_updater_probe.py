#!/usr/bin/env python3
"""Probe feed updaters + logs on Ethereum; LaChain oracle functions."""
import json, sys
from web3 import Web3

eth = Web3(Web3.HTTPProvider("https://ethereum-rpc.publicnode.com", request_kwargs={"timeout": 60}))
lac = Web3(Web3.HTTPProvider("https://rpc1.mainnet.lachain.network", request_kwargs={"timeout": 60}))
print("eth block:", eth.eth.block_number, "ts:", eth.eth.get_block("latest").timestamp, file=sys.stderr)
print("lac block:", lac.eth.block_number, file=sys.stderr)

FEED_LAC = Web3.to_checksum_address("0xF3585f9D9a671e630055Ce0c436AA214954ce6D4")
FEED_RPC = Web3.to_checksum_address("0x5da9a0bc9342b801640366e61592EE50E0285437")
CANDIDATES = [
    "0x6A138bd6d69Feb3C2f5426549e60E644778AD04C",  # deployer EOA from audit
    "0x6C15e4Bc44CC5674b1d7956D0e9596d2E509eD24",  # multisig
    "0x8D3bdc2E35097B46Cd5Cc13808e47d79AF5FbB3C",  # LaChain admin
    "0x0000000000000000000000000000000000000000",
]
AUTH_ABI = [{"name":"authorizedAddresses","outputs":[{"type":"bool"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"},
            {"name":"owner","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
            {"name":"pendingOwner","outputs":[{"type":"address"}],"inputs":[],"stateMutability":"view","type":"function"},
            {"name":"boundChecksEnabled","outputs":[{"type":"bool"}],"inputs":[],"stateMutability":"view","type":"function"},
            {"name":"minAnswer","outputs":[{"type":"int256"}],"inputs":[],"stateMutability":"view","type":"function"},
            {"name":"maxAnswer","outputs":[{"type":"int256"}],"inputs":[],"stateMutability":"view","type":"function"},
            {"name":"latestRound","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"}]
out = {}
for nm, feed in (("LAC", FEED_LAC), ("RPC", FEED_RPC)):
    c = eth.eth.contract(address=feed, abi=AUTH_ABI)
    rec = {}
    for fn in ("owner","pendingOwner","boundChecksEnabled","minAnswer","maxAnswer","latestRound"):
        try: rec[fn] = str(getattr(c.functions, fn)().call())
        except Exception as e: rec[fn+"_err"] = str(e)[:80]
    rec["authorized"] = {}
    for cand in CANDIDATES:
        try: rec["authorized"][cand] = c.functions.authorizedAddresses(Web3.to_checksum_address(cand)).call()
        except Exception as e: rec["authorized"][cand] = "err:"+str(e)[:60]
    out[nm] = rec

# eth_getLogs on feed LAC: AnswerUpdated topic, last 5000 blocks
topic = Web3.keccak(text="AnswerUpdated(int256,uint256,uint256)").hex()
try:
    latest = eth.eth.block_number
    logs = eth.eth.get_logs({"address": FEED_LAC, "topics": [topic], "fromBlock": latest-5000, "toBlock": latest})
    out["logs_last5000"] = [{"block": l["blockNumber"], "tx": l["transactionHash"].hex(), "data": l["data"].hex()[:130]} for l in logs[-5:]]
    out["logs_count"] = len(logs)
except Exception as e:
    out["logs_err"] = str(e)[:200]

# LaChain oracle probes
LAC_ORACLE = Web3.to_checksum_address("0x4E07BDEec540D3a2318A91fAEe130E692506a360")
cLAC = Web3.to_checksum_address("0x465ebFCeB3953e2922B686F2B4006173664D16cE")
probes = {
    "owner()": "0x8da5cb5b",
    "updateAnswer(int256)": "0xa87a20ce",
    "priceFeeds(address)": "0x9dcb511a",
    "fixedPrices(address)": "0xe983fe25",
    "getConfig(address)": "0xe48a5f7b",
    "admin()": "0xf851ee77",
}
oracle_probe = {}
for name, sel in probes.items():
    data = sel
    if name in ("priceFeeds(address)","fixedPrices(address)","getConfig(address)"):
        data = sel + "0"*24 + cLAC[2:].lower()
    try:
        r = lac.eth.call({"to": LAC_ORACLE, "data": data})
        oracle_probe[name] = r.hex()[:130]
    except Exception as e:
        oracle_probe[name] = "revert"
out["lachain_oracle_probe"] = oracle_probe
# getUnderlyingPrice with proper arg
sel = Web3.keccak(text="getUnderlyingPrice(address)")[:4].hex()
try:
    r = lac.eth.call({"to": LAC_ORACLE, "data": sel + "0"*24 + cLAC[2:].lower()})
    out["lachain_oracle_getUnderlyingPrice_cLAC"] = str(int(r.hex(), 16))
except Exception as e:
    out["lachain_oracle_getUnderlyingPrice_cLAC"] = "err "+str(e)[:100]
# code compare
eth_code = eth.eth.get_code(Web3.to_checksum_address("0xfbA2712d3bbcf32c6E0178a21955b61FE1FF424A")).hex()
lac_code = lac.eth.get_code(LAC_ORACLE).hex()
out["oracle_code"] = {"eth_len": len(eth_code)//2, "lac_len": len(lac_code)//2, "same": eth_code == lac_code,
                      "eth_md5": Web3.keccak(hexstr=eth_code).hex()[:18], "lac_md5": Web3.keccak(hexstr=lac_code).hex()[:18]}
print(json.dumps(out, indent=1, default=str))
