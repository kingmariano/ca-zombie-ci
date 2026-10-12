#!/usr/bin/env python3
"""Fetch verified sources for related Cap Finance contracts (oracles, treasuries, pools, routers, tokens)."""
import json, os, urllib.request, time

ADDRS = [
    "0x08AAcc8FA22133b97324765B973704Ca286a6D76",  # v1 oracle
    "0xE195a15533c01c8cD6b28f09066842486f80F8f2",  # v2 oracle
    "0x283C41b726634fBD6B72aA22741B202DB7E56aaC",  # v2 treasury
    "0x5ABFF8F8D5b13253dCAB1e427Fdb3305cA620119",  # v2 router
    "0x17f81a65F922dC0e50Fc4375E33A36Cb8089850c",  # v2 dark oracle
    "0x3E4CdcDC5E3F46DCe516adB428d107CE62A6D24a",  # v3 pool
    "0xFc4351357748d03CC938807e68A725E445C44995",  # v3 CLP
    "0x764E7f8798D8193bEd69030AE66eb304968C3F93",  # v3 gov
    "0x29163356bBAF0a3bfeE9BA5a52a5C6463114Cb5f",  # ETH pool rewards
    "0x10f2f3B550d98b6E51461a83AD3FE27123391029",  # USDC pool rewards
    "0x031d35296154279dc1984dcd93e392b1f946737b",  # CAP token (impl probe)
]

key = os.environ["ETHERSCANV2_API_KEY"]
outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sources")
os.makedirs(outdir, exist_ok=True)

for a in ADDRS:
    url = (f"https://api.etherscan.io/v2/api?chainid=42161&module=contract"
           f"&action=getsourcecode&address={a}&apikey={key}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        d = json.load(urllib.request.urlopen(req, timeout=30))
        r = d["result"][0]
    except Exception as e:
        print(a, "ERR", e)
        continue
    rec = {
        "address": a,
        "contract_name": r.get("ContractName"),
        "compiler": r.get("CompilerVersion"),
        "proxy": r.get("Proxy"),
        "implementation": r.get("Implementation"),
        "abi": r.get("ABI"),
        "source": r.get("SourceCode"),
    }
    fn = os.path.join(outdir, f"{a.lower()}_{r.get('ContractName')}.json")
    with open(fn, "w") as f:
        json.dump(rec, f, indent=1)
    print(f"{a} -> {r.get('ContractName')} (src {len(r.get('SourceCode') or '')} chars)")
    time.sleep(0.3)
