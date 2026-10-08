#!/usr/bin/env python3
"""Safe updater details + feed round history (read-only, Ethereum)."""
import json
from web3 import Web3
eth = Web3(Web3.HTTPProvider("https://ethereum-rpc.publicnode.com", request_kwargs={"timeout": 60}))
FEED_LAC = Web3.to_checksum_address("0xF3585f9D9a671e630055Ce0c436AA214954ce6D4")
FEED_RPC = Web3.to_checksum_address("0x5da9a0bc9342b801640366e61592EE50E0285437")
SAFE = Web3.to_checksum_address("0xBf41C0DC65ea4879D8A74E0a69737AF7B3e0Fa13")
EXECUTOR = Web3.to_checksum_address("0xaCDC3EBA833Ec6Edb048C109956440Fcf0985314")

AUTH = [{"name":"authorizedAddresses","outputs":[{"type":"bool"}],"inputs":[{"name":"","type":"address"}],"stateMutability":"view","type":"function"}]
SAFE_ABI = [
    {"name":"getThreshold","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"getOwners","outputs":[{"type":"address[]"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"VERSION","outputs":[{"type":"string"}],"inputs":[],"stateMutability":"view","type":"function"},
]
ROUND_ABI = [
    {"name":"getRoundData","outputs":[{"name":"roundId","type":"uint80"},{"name":"answer","type":"int256"},{"name":"startedAt","type":"uint256"},{"name":"updatedAt","type":"uint256"},{"name":"answeredInRound","type":"uint80"}],"inputs":[{"name":"_roundId","type":"uint80"}],"stateMutability":"view","type":"function"},
    {"name":"latestRound","outputs":[{"type":"uint256"}],"inputs":[],"stateMutability":"view","type":"function"},
    {"name":"getCurrentPhaseInfo","outputs":[{"name":"phaseId","type":"uint16"},{"name":"roundId","type":"uint64"}],"inputs":[],"stateMutability":"view","type":"function"},
]
out = {}
for nm, feed in (("LAC", FEED_LAC), ("RPC", FEED_RPC)):
    c = eth.eth.contract(address=feed, abi=AUTH + ROUND_ABI)
    rec = {}
    for cand, label in ((SAFE,"safe_updater"),(EXECUTOR,"executor_eoa")):
        rec["authorized_"+label] = c.functions.authorizedAddresses(cand).call()
    lr = c.functions.latestRound().call()
    rec["latestRound"] = str(lr)
    rec["phase"] = c.functions.getCurrentPhaseInfo().call()
    rounds = []
    for i in range(0, 6):
        try:
            rd = c.functions.getRoundData(lr - i).call()
            rounds.append({"round": str(rd[0]), "answer": str(rd[1]), "updatedAt": rd[3]})
        except Exception as e:
            rounds.append({"round": str(lr-i), "err": str(e)[:60]})
    rec["recent_rounds"] = rounds
    out[nm] = rec
safe = eth.eth.contract(address=SAFE, abi=SAFE_ABI)
out["safe"] = {"address": SAFE,
               "threshold": safe.functions.getThreshold().call(),
               "owners": safe.functions.getOwners().call(),
               "version": safe.functions.VERSION().call()}
print(json.dumps(out, indent=1, default=str))
