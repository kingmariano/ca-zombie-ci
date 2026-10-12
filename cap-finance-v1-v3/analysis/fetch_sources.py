#!/usr/bin/env python3
"""Fetch verified sources + ABIs for Cap Finance contracts (Arbitrum) from Etherscan V2.
Saves to analysis/sources/. Read-only. No secrets written to files."""
import json, os, sys, time, urllib.request

ADDRS = [
    "0x1058AFe66BB5b79C295CCCE51016586949Bc4e8d",
    "0x9BC357bc5b312AaCD41a84F3C687F031B8786853",
    "0xA55Eee92a46A50A4C65908F28A0BE966D3e71633",
    "0xCAEc650502F15c1a6bFf1C2288fC8F819776B2eC",
    "0xbEd32937D8A5D1421241F52809908f1a17D75bDb",
    "0xC8CDd2Ea6A5149ced1F2d225D16a775ee081C67D",
    "0xE0cCd451BB57851c1B2172c07d8b4A7c6952a54e",
    "0x958cc92297e6F087f41A86125BA8E121F0FbEcF2",
    "0xf16033d20adda47dc99ea291d0f4c4fef2ff47af",
    "0x031d35296154279dc1984dcd93e392b1f946737b",
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
    name = r.get("ContractName") or "unknown"
    rec = {
        "address": a,
        "contract_name": name,
        "compiler": r.get("CompilerVersion"),
        "proxy": r.get("Proxy"),
        "implementation": r.get("Implementation"),
        "abi": r.get("ABI"),
        "source": r.get("SourceCode"),
    }
    fn = os.path.join(outdir, f"{a.lower()}_{name}.json")
    with open(fn, "w") as f:
        json.dump(rec, f, indent=1)
    print(f"{a} -> {name} (src {len(r.get('SourceCode') or '')} chars, abi {len(r.get('ABI') or '')})")
    time.sleep(0.3)
