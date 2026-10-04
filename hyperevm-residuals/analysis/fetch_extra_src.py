#!/usr/bin/env python3
"""Fetch extra addresses (live impls discovered via EIP-1967) into analysis/nest_src."""
import json, os, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "nest_src")
ENV = "/home/heisenberg/CA/.env"
KEY = None
for line in open(ENV):
    if line.startswith("ETHERSCANV2_API_KEY="):
        KEY = line.split("=", 1)[1].strip().strip('"').strip("'")

EXTRA = [
    ("VotingEscrow_impl_live", "0xf70526a0089fdc334814c3498ca1ba30c25aba91"),
    ("Voter_impl_live", "0x2d70695c2f32c6b692370318436ef18d5c4677c1"),
    ("Minter_impl_live", "0x13369f61c13bd809984855ad26b1bf7780da8fb8"),
    # support contracts for CL
    ("AlgebraPool_impl_probe", "0x0000000000000000000000000000000000000000"),  # placeholder, replaced below
]

def fetch(addr):
    url = ("https://api.etherscan.io/v2/api?chainid=999&module=contract&action=getsourcecode"
           f"&address={addr}&apikey={KEY}")
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.loads(r.read())
        except Exception as e:
            if attempt == 4:
                return {"error": str(e)}
            time.sleep(2 * (attempt + 1))

def main():
    for label, addr in EXTRA:
        if addr == "0x0000000000000000000000000000000000000000":
            continue
        path = os.path.join(OUT, f"{label}__{addr}.json")
        d = fetch(addr)
        json.dump(d, open(path, "w"))
        res0 = d.get("result")
        if isinstance(res0, list) and res0 and isinstance(res0[0], dict):
            res0 = res0[0]
        elif not isinstance(res0, dict):
            res0 = {}
        sc = res0.get("SourceCode") or ""
        files = 1
        if sc.startswith("{"):
            try:
                files = len(json.loads(sc.strip("{}")).get("sources", {})) if sc.startswith("{{") else len(json.loads(sc).get("sources", {}))
            except Exception:
                files = -1
        print(f"{label} {addr} status={d.get('status')} name={res0.get('ContractName')} verified={bool(sc)} files={files}")
        time.sleep(0.3)
    print("done")

if __name__ == "__main__":
    main()
