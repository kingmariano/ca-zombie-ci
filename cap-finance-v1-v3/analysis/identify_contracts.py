#!/usr/bin/env python3
"""Identify all contracts created by Cap deployers: name, balance, role."""
import json, os, urllib.request, time

key = os.environ["ETHERSCANV2_API_KEY"]
base = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(base, "state", "deployer-creations.json")))
bal = {b["addr"]: b["nonzero"] for b in json.load(open(os.path.join(base, "state", "deployer-contract-balances.json")))}

for label, creations in d.items():
    print(f"\n===== deployer {label}: {len(creations)} contracts")
    for c in creations:
        a = c["contract"]
        nz = bal.get(a, [])
        if not nz:
            continue  # only print funded/interesting
        url = (f"https://api.etherscan.io/v2/api?chainid=42161&module=contract&action=getsourcecode"
               f"&address={a}&apikey={key}")
        try:
            r = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=30))["result"][0]
            name = r.get("ContractName")
            prox = r.get("Proxy")
        except Exception as e:
            name, prox = f"ERR {e}", "?"
        print(f"  {a} block={c['block']} name={name!r} proxy={prox} balances={nz}")
        time.sleep(0.2)
