#!/usr/bin/env python3
"""Build selector -> function maps for Ionic diamond extensions from verified source.

Reads src_ext_*/main.sol plus provided on-chain selector lists (JSON) and matches.
"""
import json
import os
import re

from eth_utils import keccak

BASE = os.path.dirname(os.path.abspath(__file__))

# on-chain selector lists (from _getExtensionFunctions())
EXT_LISTS = {
    "0x83863DD9Fa107A77f0634039b9845FD716aE6690": [  # cToken CErc20Delegate
        "0xa7b820df", "0xb0d58e49", "0x135f1334", "0x067db1b3", "0xb2a02ff1",
        "0x3b1d21a2", "0xf5e3c462", "0x2608f818", "0x0e752702", "0xc5ebeaec",
        "0x852a12e3", "0xdb006a75", "0xa0712d68", "0x56e67728", "0x2c436e5b", "0xcb2ef6f7",
    ],
    "0x717a3195922BD489474C021B4497110751977ABE": [  # cToken CTokenFirstExtension
        "0x7f15e216", "0x17bfdfbc", "0xc37f68e2", "0x3c3b4b89", "0x4aeb3d9a",
        "0xcfcd4c07", "0x35daea64", "0xb1e23dbb", "0xac9650d8", "0x3af9e669",
        "0x73acee98", "0xa6afed95", "0xbd6d894d", "0xf8f9da28", "0xae9d70b0",
        "0xfca7820b", "0xb0a19076", "0x34154d4c", "0xf2b3abbd", "0x91dd36c6",
        "0x70a08231", "0x095ea7b3", "0xdd62ed3e", "0x23b872dd", "0xa9059cbb",
    ],
    "0x4F6462b8B6c65916d9b585Bc4d8276505a774735": [  # Comptroller
        "0x6a56947e", "0x6d35bf91", "0xefcb03dd", "0x9614b53b", "0xb1034882",
        "0x2ccf47a4", "0x5d72de62", "0x632e5142", "0xc90c20b1", "0xc488847b",
        "0x5ec88c79", "0x41c728b9", "0xbdcdc258", "0xd02f7351", "0x5fc7e71e",
        "0x24008a62", "0x779b2294", "0xda3d454c", "0x51dff989", "0xeabe7d91",
        "0x4ef4c3e1", "0xede4edd0", "0xc2998238", "0x1976828e", "0x7e361b11",
        "0xb9b5b153", "0xc8c9c975", "0x952adf5a", "0x4fd42e17", "0xe4028eee",
        "0x317b0b77", "0x55ee1fe1", "0x929fe9a1", "0xabfceffc", "0xb452ef62", "0x94543c15",
    ],
    "0x139b09e9BA6D5E57b23e21f930587647119A1213": [  # ComptrollerFirstExtension
        "0x7f15e216", "0x783f1096", "0x3a72cb5e", "0xfb6243fa", "0xb3253801",
        "0x2273f40e", "0xf874eb0c", "0x088e0fce", "0xee5b9a2f", "0xa5fb4857",
        "0x109908ce", "0x4a76e727", "0xd9e0ea6b", "0x3605b51b", "0xd01f63f5",
        "0xe6806591", "0x15c3b9b0", "0x32abcdbe", "0xb0772d0b", "0x819605a8",
        "0x2d70db78", "0x8ebf6364", "0x18c882a5", "0x3bcf7ec1", "0x5f5af1aa",
        "0x391957d7", "0xbe945a64", "0x51c8491d", "0xc76ae260", "0xd219fca7",
        "0x607ef6c1", "0x51a485e4", "0x692fd2a9",
    ],
    "0x28241E3590a7fC0bC9eAe34188b3390B68cC9768": [  # ComptrollerPrudentiaCapsExt
        "0x8d3df1b2", "0x0dd0cefa", "0xdbfb09d6", "0x2d6af6b0",
    ],
}

EXT_SRC = {
    "0x83863DD9Fa107A77f0634039b9845FD716aE6690": "src_ext_0x83863DD9Fa107A77f0634039b9845FD716aE6690/main.sol",
    "0x717a3195922BD489474C021B4497110751977ABE": "src_ext_0x717a3195922BD489474C021B4497110751977ABE/main.sol",
    "0x4F6462b8B6c65916d9b585Bc4d8276505a774735": "src_ext_0x4F6462b8B6c65916d9b585Bc4d8276505a774735/main.sol",
    "0x139b09e9BA6D5E57b23e21f930587647119A1213": "src_ext_0x139b09e9BA6D5E57b23e21f930587647119A1213/main.sol",
    "0x28241E3590a7fC0bC9eAe34188b3390B68cC9768": "src_ext_0x28241E3590a7fC0bC9eAe34188b3390B68cC9768/main.sol",
}

TYPE_FIX = [
    (r"\bcalldata\b", ""),
    (r"\bmemory\b", ""),
    (r"\bindexed\b", ""),
    (r"\bpayable\b", ""),
    (r"\buint\b", "uint256"),
    (r"\bint\b", "int256"),
]


def norm_type(t: str) -> str:
    t = t.strip()
    for pat, rep in TYPE_FIX:
        t = re.sub(pat, rep, t)
    # remove parameter name if present (e.g., 'address account')
    parts = t.split()
    if len(parts) > 1 and not parts[1].startswith("["):
        t = parts[0]
    if "(" in t:  # tuple/struct -> not resolvable simply
        return t
    return t


def extract_signatures_from_dir(dirpath: str):
    sigs = []
    for root, _, files in os.walk(dirpath):
        for fn in files:
            if not fn.endswith(".sol"):
                continue
            src = open(os.path.join(root, fn)).read()
            sigs.extend(_extract_from_src(src))
    return sorted(set(sigs))


def _extract_from_src(src: str):
    sigs = []
    # strip comments to avoid false positives
    src = re.sub(r"//[^\n]*", "", src)
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    for m in re.finditer(r"function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(([^;{)]*)\)", src):
        name, args = m.group(1), m.group(2)
        types = []
        ok = True
        depth = 0
        cur = ""
        for ch in args:
            if ch == "," and depth == 0:
                types.append(cur)
                cur = ""
            else:
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                cur += ch
        if cur.strip():
            types.append(cur)
        norm = [norm_type(t) for t in types]
        if any("(" in t for t in norm):
            ok = False
        if ok:
            sigs.append(f"{name}({','.join(norm)})")
    # public state variables -> getters
    for m in re.finditer(r"\b([A-Za-z_][A-Za-z0-9_]*)\s+public\s+([A-Za-z_][A-Za-z0-9_]*)\s*(=|;)", src):
        typ, name = m.group(1), m.group(2)
        typ = re.sub(r"\bpayable\b", "", typ).strip()
        if typ.endswith("[]"):
            sigs.append(f"{name}(uint256)")
        elif typ.startswith("mapping"):
            # count keys
            n = typ.count("=>")
            keys = ["address"] * n if n else ["address"]
            sigs.append(f"{name}({','.join(keys)})")
        else:
            sigs.append(f"{name}()")
    return sigs


def main():
    out = {}
    for ext, selectors in EXT_LISTS.items():
        d = os.path.dirname(EXT_SRC[ext])
        sigs = extract_signatures_from_dir(os.path.join(BASE, d))
        smap = {}
        for s in sigs:
            smap["0x" + keccak(text=s)[:4].hex()] = s
        matched = {}
        missing = []
        for sel in selectors:
            matched[sel] = smap.get(sel, "UNKNOWN")
            if matched[sel] == "UNKNOWN":
                missing.append(sel)
        out[ext] = {"source": EXT_SRC[ext], "selectors": matched, "unmatched": missing}
        print(f"== {ext} ({EXT_SRC[ext]}) ==")
        for sel, sig in matched.items():
            print(f"  {sel}  {sig}")
        print()
    with open(os.path.join(BASE, "selector_map.json"), "w") as f:
        json.dump(out, f, indent=1)


if __name__ == "__main__":
    main()
