#!/usr/bin/env python3
"""Fetch verified source from Etherscan V2 for Granary contracts. Key from env only."""
import json, os, urllib.request, time

HERE = os.path.dirname(os.path.abspath(__file__))
KEY = os.environ.get("ETHERSCANV2_API_KEY", "")
if not KEY:
    raise SystemExit("no ETHERSCANV2_API_KEY in env")

TARGETS = [
    # (chainid, address, label)
    (10, "0x9aeefef549323511e027d70562f0c7edcdeb294c", "op-oracle"),
    (10, "0x8fd4af47e4e63d1d2d45582c3286b4bd9bb95dfe", "op-pool"),
    (10, "0xdDE5dC81e40799750B92079723Da2acAF9e1C6D6", "op-provider"),
    (1088, "0xc4ae6cea0f15f5a44e0f8eea1d516af2eccb9709", "metis-oracle"),
    (1088, "0x65dec665ea1e96ee5203db321b5cd413b81b2bd2", "metis-pool"),
    (8453, "0x5a3423210536d930150080f699248edebc65e2b4", "base-avax-oracle"),
    (1, "0x9546f673ef71ff666ae66d01fd6e7c6dae5a9995", "eth-oracle"),
    (1, "0xb702ce183b4e1faa574834715e5d4a6378d0eed3", "eth-avax-base-pool"),
    (56, "0x417ca1091fa4c329cee19452851dff46902440a5", "bsc-oracle"),
    (42161, "0xe12e084fc4550387cb2b252b5f289ba38b755354", "arb-oracle"),
    (250, "0x59dea1331503c8fb92f5f68df2a7f97a801a4ea9", "ftm-oracle"),
    (43114, "0x5a3423210536d930150080f699248edebc65e2b4", "avax-oracle"),
]

def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "granary-audit/1.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.loads(r.read().decode())

os.makedirs(os.path.join(HERE, "src"), exist_ok=True)
for cid, addr, label in TARGETS:
    url = (f"https://api.etherscan.io/v2/api?chainid={cid}&module=contract&action=getsourcecode"
           f"&address={addr}&apikey={KEY}")
    try:
        d = get(url)
        res = d.get("result")
        if isinstance(res, list) and res:
            r0 = res[0]
            src = r0.get("SourceCode", "")
            out = {
                "chainid": cid, "address": addr, "label": label,
                "ContractName": r0.get("ContractName"),
                "CompilerVersion": r0.get("CompilerVersion"),
                "Proxy": r0.get("Proxy"), "Implementation": r0.get("Implementation"),
                "ABI": r0.get("ABI"),
                "SourceCode": src,
            }
            with open(os.path.join(HERE, "src", f"{label}.json"), "w") as f:
                json.dump(out, f, indent=1)
            print(f"OK {label} {addr} name={r0.get('ContractName')} src_len={len(src)} proxy={r0.get('Proxy')} impl={r0.get('Implementation')}")
        else:
            print(f"FAIL {label} {addr}: {str(d)[:200]}")
    except Exception as e:
        print(f"ERR {label} {addr}: {e}")
    time.sleep(0.4)
