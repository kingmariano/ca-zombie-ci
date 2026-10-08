#!/usr/bin/env python3
"""Fetch verified sources from Flare Blockscout (flare-explorer.flare.network) for the Kinetic target set."""
import json, os, sys, urllib.request

BASE = "https://flare-explorer.flare.network/api/v2/smart-contracts/"
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "analysis", "src")
os.makedirs(OUT, exist_ok=True)

ADDRS = [
    # comptrollers (unitroller proxies) + impls resolved later
    "0x15F69897E6aEBE0463401345543C26d1Fd994abB",
    "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8",
    # markets
    "0xad7e7989796414c9572da9854DEb1B920724fd09",
    "0xD1b7A5eFa9bd88F291F7A4563a8f6185c0249CB3",
    "0x870f7B89F0d408D7CA2E6586Df26D00Ea03aA358",
    "0xDEeBaBe05BDA7e8C1740873abF715f16164C29B8",
    "0x1e5bBC19E0B17D7d38F318C79401B3D16F2b93bb",
    "0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656",
    "0x5C2400019017AE61F811D517D088Df732642DbD0",
    "0x40eE5dfe1D4a957cA8AC4DD4ADaf8A8fA76b1C16",
    "0x76809aBd690B77488Ffb5277e0a8300a7e77B779",
    "0xb84F771305d10607Dd086B2f89712c0CeD379407",
    # oracle
    "0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b",
]

def fetch(addr):
    url = BASE + addr
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 research"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)

summary = {}
for a in ADDRS:
    try:
        d = fetch(a)
    except Exception as e:
        print(f"FAIL {a}: {e}"); continue
    name = d.get("name") or d.get("contract_name")
    impl = d.get("implementations") or []
    fn = os.path.join(OUT, a.lower() + ".json")
    with open(fn, "w") as f:
        json.dump(d, f)
    summary[a] = {
        "name": name,
        "is_proxy": bool(d.get("is_proxy") or impl),
        "implementations": [i.get("address") if isinstance(i, dict) else i for i in impl],
        "file_path": d.get("file_path"),
        "source_len": len(d.get("source_code") or ""),
        "has_abi": bool(d.get("abi")),
    }
    print(json.dumps({a: summary[a]}))

with open(os.path.join(OUT, "_index.json"), "w") as f:
    json.dump(summary, f, indent=2)
