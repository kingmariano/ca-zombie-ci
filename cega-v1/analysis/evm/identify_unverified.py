"""Identify UNVERIFIED contracts: strings in bytecode + batched function probes."""
import json
import re
import sys

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

PROBES = [
    ("name()", "0x06fdde03"),
    ("symbol()", "0x95d89b41"),
    ("owner()", "0x8da5cb5b"),
    ("feeRecipient()", "0x46904840"),
    ("asset()", "0x38d52e0f"),
    ("underlyingToken()", "0x2495a599"),
    ("merkleRoot()", "0x2eb4a7ab"),
    ("token()", "0xfc0c546a"),
    ("paused()", "0x5c975abb"),
    ("product()", "0x04dfb7db"),   # guess
    ("cegaState()", "0xce7a26f4"),  # guess
    ("vaultAddresses()", "0x71bb4d41"),  # guess
]

out = {}
for cid, addrs in UNVERIFIED.items():
    out[cid] = {}
    codes = lib.rpc_batch(cid, [("eth_getCode", [a, "latest"]) for a in addrs], chunk=5)
    calls = []
    index = []
    for i, a in enumerate(addrs):
        for label, sel in PROBES:
            calls.append(("eth_call", [{"to": a, "data": sel}, "latest"]))
            index.append((a, label))
    res = lib.rpc_batch(cid, calls, chunk=5)
    probed = {}
    for (a, label), r in zip(index, res):
        probed.setdefault(a, {})[label] = r if r else "revert-or-error"
    for i, a in enumerate(addrs):
        code = codes[i] or "0x"
        raw = bytes.fromhex(code[2:])
        strs = sorted(set(re.findall(rb"[\x20-\x7e]{5,}", raw)), key=len, reverse=True)
        out[cid][a] = {
            "code_size": len(code) // 2 - 1,
            "strings": [s.decode() for s in strs][:50],
            "probes": probed[a],
        }
        print("=" * 30, cid, a, len(code) // 2 - 1)
        for s in out[cid][a]["strings"][:22]:
            print("   str:", s)
        print("   probes:", json.dumps(probed[a]))

lib.save_json("/home/heisenberg/CA/cega-v1/analysis/evm/unverified_probe.json", out)
