#!/usr/bin/env python3
"""Extract dispatcher selectors from bytecode and resolve via 4byte.directory."""
import json
import os
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

TARGETS = {
    "poolB_impl": "0xe3a900e0f0aaae2cd79c5849fa465470feb5f4f8",
    "poolA_impl": "0x8cc50713d3c7525fc4fc87514aa3beffeab92e96",
    "configB_impl": "0x12d1f5bc35397dfef5d41a77a6865151efd6233a",
    "configA_maybeimpl": "0x1C5D4B5DFC1A47e5Db839Cb8A0Fb36bAb1E986B7",
    "treasury_0x5dc4": "0x5dc4dd7969944300083994c60e2ce67b4b81457c",
    "oracleB": "0xc131bA07e9a6533e46Ca539280d02a42AC9C131a",
    "oracleA": "0xce767E508A17321C25117b44d246e4611bbEcFE4",
}


def extract_selectors(code: str):
    """PUSH4 values directly followed by EQ (0x14) = dispatcher entries."""
    b = bytes.fromhex(code[2:])
    out = []
    i = 0
    while i < len(b):
        op = b[i]
        if op == 0x63 and i + 4 < len(b):  # PUSH4
            val = b[i + 1:i + 5]
            nxt = b[i + 5] if i + 5 < len(b) else None
            if nxt == 0x14:  # EQ
                out.append("0x" + val.hex())
            i += 5
        else:
            i += 1
    return sorted(set(out))


def resolve(sel):
    url = f"https://www.4byte.directory/api/v1/signatures/?hex_signature={sel}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.load(r)
        res = d.get("results", [])
        return res[0]["text_signature"] if res else None
    except Exception as e:
        return f"<lookup err {e}>"


def main():
    report = {}
    for name, addr in TARGETS.items():
        code = rpc("eth_getCode", [addr, "latest"])
        if not isinstance(code, str) or len(code) < 4:
            print(name, "NO CODE", code)
            continue
        sels = extract_selectors(code)
        report[name] = {"address": addr, "code_bytes": (len(code) - 2) // 2, "selectors": {}}
        print(f"===== {name} {addr} code={report[name]['code_bytes']}B selectors={len(sels)} =====")
        for s in sels:
            sig = resolve(s)
            report[name]["selectors"][s] = sig
            print(f"  {s} {sig}")
    json.dump(report, open(os.path.join(RAW, "selectors.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
