"""Extract PUSH4 constants from runtime bytecode and match against local ABIs + 4byte.directory."""
import json
import re
import subprocess
import sys
import urllib.request

sys.path.insert(0, "/home/heisenberg/CA/cega-v1/analysis/evm")
import lib

UNVERIFIED = {
    1: [
        "0x0082031f381d8ba06e882a151dce5d4a14bf652d",
        "0x0fb5f1f0dba5b7b5fcf5742f48463585bc32dfe2",
        "0x145a00bc40b5af0848e62c64b6e3b8226b146c0e",
        "0x1aa36e3473d8a1e0b9649d49d262ba50f920de10",
        "0x4e482af5547db12aadbc9040cda438adcba44ae8",
        "0x566b5bb99106144f843ae5365f3dfc2f6b406b93",
        "0x5b34ec104051f10a6cbedaaf2b2bf33f2a2c91aa",
        "0x812fe80fea65fdeb590f40056ab3c878223fbe1e",
        "0xb029dd8adbd507b2c456a550ac340076b1fee7b2",
        "0xb09b50f1be17ba3ef08879a895a6b0b98600ee00",
        "0xb517944479e3e85ec1d26f607db9193706733d30",
        "0xe1ebd88ca95ea328c8797fa2762d4df717c75200",
    ],
    42161: [
        "0x3c7442689b4d86ea1bc70fca5fda5ccc8b812b85",
        "0x6479b4925498031e1812bfc46e92e35eda149317",
    ],
}

# collect local ABI selectors
import glob

LOCAL = {}
for f in glob.glob("/home/heisenberg/CA/cega-v1/analysis/sources/*.abi"):
    try:
        abi = json.load(open(f))
    except Exception:
        continue
    for e in abi:
        if e.get("type") == "function":
            sig = e["name"] + "(" + ",".join(i["type"] for i in e["inputs"]) + ")"
            try:
                sel = subprocess.check_output(["cast", "sig", sig], text=True).strip()
            except Exception:
                continue
            LOCAL[sel] = sig


def push4s(code):
    raw = bytes.fromhex(code[2:])
    out = []
    i = 0
    while i < len(raw):
        op = raw[i]
        if op == 0x63 and i + 4 < len(raw):  # PUSH4
            out.append("0x" + raw[i + 1 : i + 5].hex())
            i += 5
        elif 0x60 <= op <= 0x7F:  # PUSH1..PUSH32
            i += 1 + (op - 0x5F)
        else:
            i += 1
    # dedupe preserving order
    seen = set()
    res = []
    for s in out:
        if s not in seen:
            seen.add(s)
            res.append(s)
    return res


FOURBYTE_CACHE = "/home/heisenberg/CA/cega-v1/analysis/evm/fourbyte_cache.json"
try:
    FOUR = json.load(open(FOURBYTE_CACHE))
except Exception:
    FOUR = {}


def lookup4byte(sel):
    if sel in FOUR:
        return FOUR[sel]
    if sel in LOCAL:
        return [LOCAL[sel]]
    try:
        url = f"https://www.4byte.directory/api/v1/signatures/?hex_signature={sel}"
        req = urllib.request.Request(url, headers={"User-Agent": "cega-tombstone/1.0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read().decode())
        names = [x["text_signature"] for x in data.get("results", [])]
    except Exception:
        names = []
    FOUR[sel] = names
    return names


out = {}
for cid, addrs in UNVERIFIED.items():
    out[cid] = {}
    for a in addrs:
        code = lib.rpc(cid, "eth_getCode", [a, "latest"])
        sels = push4s(code)
        matched = {}
        for s in sels:
            names = lookup4byte(s)
            if names:
                matched[s] = names
        out[cid][a] = {"code_size": len(code) // 2 - 1, "selectors": sels, "matched": matched}
        print("=" * 30, cid, a, len(code) // 2 - 1, "selectors:", len(sels), "matched:", len(matched))
        for s, names in matched.items():
            print(f"   {s} -> {names[:3]}")
    lib.save_json(FOURBYTE_CACHE, FOUR)

lib.save_json("/home/heisenberg/CA/cega-v1/analysis/evm/unverified_selectors.json", out)
