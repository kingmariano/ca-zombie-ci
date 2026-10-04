#!/usr/bin/env python3
"""Positions: aToken/vToken balances of key actors + contract x asset matrix."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u, addr_from_word  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

SEL_BAL = "0x70a08231"
ZERO = "0x0000000000000000000000000000000000000000"

ACTORS = {
    "attacker": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
    "admin_0x0dd0": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
    "safe_0xD3E0": "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F",
    "deployer": "0xc7461891c88f6a609d9149d2826704bd178a80de",
    "aclAdminA": "0x3d0c177E035C30bb8681e5859EB98d114b48b935",
    "safeOwner1": "0x6d0F4Cec05a7066D3f509A732D59Ede630989053",
    "safeOwner2": "0x75eF5d635388d7C97425596CE50c11844234128B",
    "early_admin1": "0x619603aebcf30ef464399ebd2ebe7d44e0bc703c",
    "early_admin2": "0x84cae48c1d393676e25875fe07ad27cce2fffbf8",
}


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    enum = json.load(open(os.path.join(RAW, "enumeration.json")))
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "markets": {}}
    # collect calls
    calls = []
    meta = []
    for mname, m in enum["markets"].items():
        out["markets"][mname] = {"pool": m["pool"], "tokens": {}, "actors": {}}
        for r in m["reserves"]:
            rd = r["reserveData"]
            for token_key in ("aTokenAddress", "variableDebtTokenAddress", "stableDebtTokenAddress"):
                tok = rd[token_key]
                if not tok or tok.lower() == ZERO:
                    continue
                out["markets"][mname]["tokens"][f"{r['symbol']}/{token_key}"] = tok
                for aname, a in ACTORS.items():
                    calls.append(("eth_call", [{"to": tok, "data": SEL_BAL + pad_a(a)}, hex(block)]))
                    meta.append((mname, r["symbol"], token_key, aname))
    res = batch(calls, timeout=180)
    for (mname, sym, tk, aname), v in zip(meta, res):
        val = dec_u(v) if isinstance(v, str) else v
        out["markets"][mname]["actors"].setdefault(aname, {})[f"{sym}/{tk}"] = val

    with open(os.path.join(RAW, "positions.json"), "w") as f:
        json.dump(out, f, indent=1)

    for mname, md in out["markets"].items():
        print(f"===== {mname} =====")
        for aname, toks in md["actors"].items():
            nz = {k: v for k, v in toks.items() if isinstance(v, int) and v != 0}
            if nz:
                print(f"  {aname}:")
                for k, v in nz.items():
                    print(f"     {k}: {v}")


if __name__ == "__main__":
    main()
