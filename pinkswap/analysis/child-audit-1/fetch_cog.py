#!/usr/bin/env python3
"""Fetch COG verified source via public Blockscout HTTP API (read-only)."""
import json, urllib.request

UA = {"User-Agent": "Mozilla/5.0 child-audit"}
url = "https://bsc.blockscout.com/api/v2/smart-contracts/0xCE1dB03de797Ffb5bFE98e3903f2CBEc841b26f8"
req = urllib.request.Request(url, headers=UA)
d = json.loads(urllib.request.urlopen(req, timeout=45).read().decode())
print("name:", d.get("name"), "| verified:", d.get("is_verified"), "| language:", d.get("language"),
      "| compiler:", d.get("compiler_version"), "| proxy:", d.get("is_proxy"))
src = d.get("source_code") or ""
print("source len:", len(src))
open("/home/heisenberg/CA/pinkswap/analysis/child-audit-1/COG_source.sol", "w").write(src)
# also print function/onlyOwner lines if any
import re
for ln, line in enumerate(src.splitlines(), 1):
    if re.search(r"function\s+(mint|burn)|onlyOwner|_mint\(|_burn\(|constructor", line):
        print(f"{ln}: {line.strip()[:150]}")
