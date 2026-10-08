#!/usr/bin/env python3
"""Check health (getAccountLiquidity) of all borrowers in the smaller Capyfi markets."""
import json, time, urllib.request
from web3 import Web3

RPC = "https://ethereum-rpc.publicnode.com"
COMPTROLLER = Web3.to_checksum_address("0x0b9af1fd73885aD52680A1aeAa7A3f17AC702afA")
TOPIC = "0x13ed6866d4e1ee6da46f845c46d7e54120883d75c5ea9a2dacc1c4ca8984ab80"
MARKETS = {
    "caLAC": "0x0568F6cb5A0E84FACa107D02f81ddEB1803f3B50",
    "caWARS": "0xf80eeec09f417Fa7FCc4A848Ef03af9dF2658d7B",
    "caWBRL": "0x93d9DdEeBf3B5DBF7D7dFC04D3804Ce5450987C8",
    "caUXD": "0x98Ac8AC56d833bD69d34F909Ac15226772FAc9aa",
    "caETHold": "0xbaA6bc4E24686d710B9318B49b0Bb16ec7C46bFA",
    "caUSDAR": "0x2437E33631327b2437170972f753E15Cb9Fd1806",
}
import os
KEY = os.environ.get("ETHERSCANV2_API_KEY")
if not KEY:
    for line in open("/home/heisenberg/CA/.env"):
        if line.startswith("ETHERSCANV2_API_KEY="):
            KEY = line.split("=",1)[1].strip().strip('"').strip("'")
            break
assert KEY, "no etherscan key"

w3 = Web3(Web3.HTTPProvider(RPC))
ct_abi = [{"name":"getAccountLiquidity","outputs":[{"type":"uint256"},{"type":"uint256"},{"type":"uint256"}],"inputs":[{"name":"account","type":"address"}],"stateMutability":"view","type":"function"},
          {"name":"getAssetsIn","outputs":[{"type":"address[]"}],"inputs":[{"name":"account","type":"address"}],"stateMutability":"view","type":"function"}]
ct = w3.eth.contract(address=COMPTROLLER, abi=ct_abi)

borrowers = set()
for name, addr in MARKETS.items():
    url = (f"https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs&address={addr}"
           f"&topic0={TOPIC}&fromBlock=0&toBlock=latest&page=1&offset=1000&apikey={KEY}")
    d = json.load(urllib.request.urlopen(url))
    res = d.get("result")
    if not isinstance(res, list):
        print(name, "ERR", str(d)[:120]); continue
    for log in res:
        data = log["data"][2:]
        borrowers.add(Web3.to_checksum_address("0x"+data[24:64]))
    print(name, "logs", len(res))

print("unique borrowers:", len(borrowers))
out = []
for b in sorted(borrowers):
    try:
        err, liq, short = ct.functions.getAccountLiquidity(b).call()
        if short > 0 or liq > 0:
            out.append({"borrower": b, "liquidity": liq, "shortfall": short})
    except Exception as e:
        out.append({"borrower": b, "error": str(e)[:80]})
print(json.dumps(out, indent=1))
open("/home/heisenberg/CA/c-13/analysis/small_markets_borrower_health.json","w").write(json.dumps(out, indent=1))
