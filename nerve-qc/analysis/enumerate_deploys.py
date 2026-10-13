#!/usr/bin/env python3
"""Enumerate Nerve deployments via Etherscan V2 (BSC) + farm pools.
Key read from ETHERSCANV2_API_KEY env; never printed."""
import json, urllib.request, os, urllib.parse, time

KEY = os.environ.get("ETHERSCANV2_API_KEY","")
BASE = "https://api.etherscan.io/v2/api"
CHAIN = "56"

def es(params):
    q = dict(params); q["chainid"]=CHAIN; q["apikey"]=KEY
    url = BASE + "?" + urllib.parse.urlencode(q)
    req = urllib.request.Request(url, headers={"User-Agent":"research/1.0"})
    return json.load(urllib.request.urlopen(req, timeout=45))

def contract_creation(addrs):
    out={}
    for i in range(0,len(addrs),20):
        r = es({"module":"contract","action":"getcontractcreation","contractaddresses":",".join(addrs[i:i+20])})
        for item in r.get("result") or []:
            out[item["contractAddress"].lower()] = item
    return out

ADDRS = [
 # funded metas
 "0x2dcCe1586b1664f41C72206900e404Ec3cA130e0",
 "0xd0fBF0A224563D5fFc8A57e4fdA6Ae080EbCf3D3",
 "0x96b849a73db2cc769b4Abe770aAb141aAC9014d6",
 # extras
 "0x97B9054122eF8888590934F0eC8E10580232E85d","0xC80Cc653392f4734201331E39a66aA8a483D29BD",
 "0xCa9d9C7800b7d1D3A1988A7d93927424a1BBEA7f","0xb1669A60a7Db67AA84e5fAF2AE3123AA99237459",
 "0xF100326c19996eaf2d8E93A503725F643e36099C","0x0144E7d25644C7ca6038F4AFBfcD3b1A119Ab3cE",
 "0xbC7477e46A95758dE5012744f7A350A4E0d03484","0x0eafAa7eD9866c1f08aC21dd0ef3395E910f7114",
 # base pools
 "0x1B3771a66ee31180906972580adE9b81AFc5fCDc","0x6C341938bB75dDe823FAAfe7f446925c66E6270c",
 "0x146CD24dCc9f4EB224DFd010c5Bf2b0D25aFA9C0",
 # impls
 "0xf642f2a626a8b732619606c493abfc2433dd2d35","0xfa97adb530b38639a83b1890ee17942804035ddf",
 "0xfcc3976ebdc240ce83e8a94bc83be5cd4ad4a053",
 # farm
 "0x2EBe8CDbCB5fB8564bC45999DAb8DA264E31f24E",
]

def main():
    cr = contract_creation(ADDRS)
    deployers = {}
    for a in ADDRS:
        item = cr.get(a.lower())
        if item:
            deployers.setdefault(item["contractCreator"].lower(), []).append((a, item.get("txHash"), item.get("blockNumber")))
            print(f"{a} creator={item['contractCreator']} block={item.get('blockNumber')} tx={item.get('txHash')}")
        else:
            print(f"{a} NO CREATION INFO")
    print("== deployers ==")
    for d, items in deployers.items():
        print(f"{d}: {len(items)} known contracts")
    # save
    with open("/home/heisenberg/CA/nerve-qc/analysis/creations.json","w") as f:
        json.dump({"creations":cr,"deployers":{k:v for k,v in deployers.items()}}, f, indent=2)

if __name__=="__main__":
    if not KEY: raise SystemExit("no ETHERSCANV2_API_KEY")
    main()
