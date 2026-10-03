#!/usr/bin/env python3
"""Parse cast facets() raw output for each chain; map selectors via symmio_abi.json.
Writes facets/<chain>_map.txt and facets/all_selectors.json (selector -> chains/facets)."""
import json, re, os, sys
from eth_utils import keccak

BASE = os.path.dirname(os.path.abspath(__file__))
CHAINS = ["base", "arb", "mantle", "blast"]

# --- load ABI, build selector map ---
with open("/tmp/opencode/symmio_abi.json") as f:
    abi = json.load(f)
sig_by_sel = {}
for item in abi:
    if item.get("type") != "function":
        continue
    ins = ",".join(i["type"] for i in item["inputs"])
    sig = f"{item['name']}({ins})"
    sel = "0x" + keccak(text=sig)[:4].hex()
    sig_by_sel[sel] = sig

# --- parse raw output like: [(0xAddr, [0xsel, ...]), (...)] ---
def parse_raw(path):
    txt = open(path).read().strip()
    facets = []
    # regex pairs
    for m in re.finditer(r"\((0x[0-9a-fA-F]{40}),\s*\[([^\]]*)\]\)", txt):
        addr = m.group(1)
        sels = [s.strip() for s in m.group(2).split(",") if s.strip()]
        facets.append((addr, sels))
    return facets

all_map = {}
for chain in CHAINS:
    raw = os.path.join(BASE, "facets", f"{chain}_facets_raw.txt")
    blk = open(os.path.join(BASE, "facets", f"{chain}_block.txt")).read().strip()
    facets = parse_raw(raw)
    all_map[chain] = {"block": blk, "facets": {}}
    lines = [f"# {chain} block={blk}"]
    for addr, sels in facets:
        lines.append(f"\n=== {addr} ({len(sels)} fns) ===")
        for s in sels:
            name = sig_by_sel.get(s, "???")
            lines.append(f"{name} {s}")
        all_map[chain]["facets"][addr] = sels
    open(os.path.join(BASE, "facets", f"{chain}_map.txt"), "w").write("\n".join(lines) + "\n")
    print(f"{chain}: {len(facets)} facets, {sum(len(s) for _, s in facets)} selectors")

# unknown selectors report
unknown = {}
for chain, d in all_map.items():
    for addr, sels in d["facets"].items():
        for s in sels:
            if s not in sig_by_sel:
                unknown.setdefault(s, []).append((chain, addr))
print(f"\nUnknown selectors: {len(unknown)}")
with open(os.path.join(BASE, "facets", "unknown_selectors.json"), "w") as f:
    json.dump(unknown, f, indent=1)
for s, locs in sorted(unknown.items()):
    print(f"{s}  {locs[0][0]}:{locs[0][1]}  (+{len(locs)-1} more)")

json.dump(all_map, open(os.path.join(BASE, "facets", "all_facets.json"), "w"), indent=1)
json.dump(sig_by_sel, open(os.path.join(BASE, "facets", "abi_selectors.json"), "w"), indent=1, sort_keys=True)
