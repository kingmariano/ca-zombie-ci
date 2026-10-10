#!/usr/bin/env python3
"""Compile the verified V3-fork pool sources with their on-chain build settings and compare the
resulting runtime bytecode against the LIVE deployed code (keyless public RPC).

Method: forge build in ci/hspool-check (solc 0.7.6, runs 200) and ci/kmpool-check (runs 800);
read the artifact deployedBytecode (solc leaves zero placeholders at immutable positions and lists
them in immutableReferences); overlay the live bytes at those positions; strip the CBOR metadata
tails from both; compare the remainder byte-for-byte.

Writes a human-readable report to ci-out/bytecode-check.txt. Never fails the workflow.
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # high-cluster/
OUT = os.path.join(ROOT, "ci-out")
os.makedirs(OUT, exist_ok=True)

JOBS = [
    {
        "name": "HyperSwapV3Pool (HyperEVM 0xe712D505…)",
        "project": "ci/hspool-check",
        "artifact": "out/HyperswapV3Pool.sol/HyperswapV3Pool.json",
        "rpc": "https://rpc.hyperliquid.xyz/evm",
        "address": "0xe712D505572b3f84C1B4deB99E1BeAb9dd0E23c9",
    },
    {
        "name": "Kumbaya UniswapV3Pool (MegaETH 0x2809696f…)",
        "project": "ci/kmpool-check",
        "artifact": "out/UniswapV3Pool.sol/UniswapV3Pool.json",
        "rpc": "https://mainnet.megaeth.com/rpc",
        "address": "0x2809696f2e42eb452c32c3d0a2dc540858c14125",
    },
]

def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=900)

def strip_metadata(hexstr):
    # ipfs-style metadata (a264697066735822…) or solc-only metadata (a164736f6c63…)
    i = hexstr.rfind("a2646970667358")
    j = hexstr.rfind("a164736f6c63")
    k = max(i, j)
    return hexstr[:k] if k != -1 else hexstr

def main():
    lines = []
    for job in JOBS:
        lines.append(f"== {job['name']} ==")
        proj = os.path.join(ROOT, job["project"])
        r = run(["forge", "build"], cwd=proj)
        if r.returncode != 0:
            lines.append(f"BUILD FAILED: {r.stderr[-800:]}")
            continue
        art = os.path.join(proj, job["artifact"])
        if not os.path.exists(art):
            lines.append(f"artifact missing: {art}")
            continue
        a = json.load(open(art))
        compiled = a["deployedBytecode"]["object"].replace("0x", "").lower()
        refs = a["deployedBytecode"].get("immutableReferences", {})
        positions = []
        for _, arr in refs.items():
            for ref in arr:
                positions.append((ref["start"], ref["length"]))
        # fetch live code
        r = run(["cast", "code", job["address"], "--rpc-url", job["rpc"]])
        if r.returncode != 0 or not r.stdout.strip().startswith("0x"):
            lines.append(f"cast code failed: {r.stderr[-300:]}")
            continue
        live = r.stdout.strip()[2:].lower()
        lines.append(f"compiled runtime: {len(compiled)//2} bytes, live: {len(live)//2} bytes, "
                     f"immutable refs: {len(positions)}")
        # overlay live bytes at immutable positions onto compiled copy
        merged = list(compiled)
        for (start, length) in positions:
            s, e = start * 2, (start + length) * 2
            merged[s:e] = live[s:e]
        merged = "".join(merged)
        # primary comparison: full overlaid code (metadata included; builds use bytecode_hash=none)
        if merged == live:
            lines.append("RESULT: MATCH — live runtime bytecode == compiled verified source "
                         "(immutables overlaid; full runtime incl. metadata identical).")
        else:
            merged_s, live_s = strip_metadata(merged), strip_metadata(live)
            if merged_s == live_s:
                lines.append("RESULT: MATCH — live runtime bytecode == compiled verified source "
                             "(immutables overlaid, metadata tails stripped).")
            else:
                n = min(len(merged_s), len(live_s))
                first = next((i for i in range(0, n, 2) if merged_s[i:i+2] != live_s[i:i+2]), None)
                diffs = sum(1 for i in range(0, n, 2) if merged_s[i:i+2] != live_s[i:i+2])
                lines.append(f"RESULT: MISMATCH — first diff at byte {first}, {diffs} differing bytes "
                             f"of {n//2} (lengths {len(merged_s)//2} vs {len(live_s)//2}).")
    report = "\n".join(lines) + "\n"
    open(os.path.join(OUT, "bytecode-check.txt"), "w").write(report)
    print(report)

if __name__ == "__main__":
    main()
