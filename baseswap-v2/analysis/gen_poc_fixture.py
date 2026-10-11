#!/usr/bin/env python3
"""Generate poc/src/TopPairs.sol from ci-out/top_pairs.json (top-N pairs by live TVL USD)."""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
n = 20
if "--n" in sys.argv:
    n = int(sys.argv[sys.argv.index("--n") + 1])
pairs = json.load(open(os.path.join(ROOT, "ci-out", "top_pairs.json")))[:n]
lines = ["// SPDX-License-Identifier: MIT",
         "pragma solidity 0.8.24;",
         "",
         "/// Auto-generated from ci-out/top_pairs.json (top pairs by live reserve USD).",
         "library TopPairs {",
         "    function get() internal pure returns (address[] memory a) {",
         f"        a = new address[]({len(pairs)});"]
for i, p in enumerate(pairs):
    lines.append(f"        a[{i}] = {p['pair']};")
lines += ["    }", "}", ""]
open(os.path.join(ROOT, "poc", "src", "TopPairs.sol"), "w").write("\n".join(lines))
print("wrote poc/src/TopPairs.sol with", len(pairs), "pairs")
for p in pairs[:5]:
    print(" ", p["pair"], p["sym0"] if "sym0" in p else "", "/", p["sym1"] if "sym1" in p else "", p["tvl_usd"])
