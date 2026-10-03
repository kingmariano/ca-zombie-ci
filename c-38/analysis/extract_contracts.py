#!/usr/bin/env python3
"""Extract contract registry (contractName/address/abi) from Tectonic app JS bundle."""
import json
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "chunk-_app-0610ff7f56ab0251.js"
data = open(path, "r", encoding="utf-8", errors="replace").read()
print(f"bundle size: {len(data)}")

# pattern: "contractName":"NAME","address":"0x...","abi":"[...]"
pat = re.compile(r'"contractName":"([^"]+)","address":"(0x[a-fA-F0-9]{40})","abi":"')
out = []
for m in pat.finditer(data):
    out.append((m.group(1), m.group(2)))
print(f"contractName/address pairs: {len(out)}")
seen = set()
for name, addr in out:
    k = (name, addr.lower())
    if k in seen:
        continue
    seen.add(k)
    print(f"{name}\t{addr}")

# also standalone address fields of interest
for key in ["tTokenAddress", "comptrollerAddress", "unitrollerAddress", "oracleAddress", "priceOracle"]:
    pat2 = re.compile(r'"' + key + r'":"(0x[a-fA-F0-9]{40})"')
    vals = sorted(set(pat2.findall(data)))
    print(f"\n{key}: {len(vals)}")
    for v in vals[:60]:
        print(f"  {v}")
