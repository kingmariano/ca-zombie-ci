#!/usr/bin/env python3
"""Extra checks: remaining aTokens, proxy admins, rescueTokens guard probe."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch, dec_u, addr_from_word  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
SEL_BAL = "0x70a08231"

ACWETH = "0x7151f90076b54961771dfdaaf600e5b8b87cee20"
ACSTS = "0x83e2613b74b2697c85416a9a1fbb043f8056990b"
HOLDERS = {
    "treasury": "0x5dc4dd7969944300083994c60e2ce67b4b81457c",
    "poolA_aacUSDC": "0x0eee208934e66a6e44517e627a2475fc891b3a38",
    "poolA_aacscUSD": "0x1acd539e2a76cf876889dd8119c1d873821551a1",
    "poolA_aacwS": "0xed01f103c284253d0824c0125f673f11c14d2ea4",
    "attacker": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
    "safe": "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F",
    "admin_0x0dd0": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
}
PROXIES = {
    "configA": "0x1C5D4B5DFC1A47e5Db839Cb8A0Fb36bAb1E986B7",
    "treasury": "0x5dc4dd7969944300083994c60e2ce67b4b81457c",
    "poolA": "0x0850A9759165B25832E2cAa3dB3f2d04dc583D4E",
    "poolB": "0x56eb1bcB2aA011517fD7bf32641E79Bd8471770e",
    "configB": "0xc9122E191d9bDaBf9b59A31C01D4e6c4cd719E89",
}


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "extra_atokens": {}, "proxies": {}, "rescue_probe": {}}

    # 1) extra aToken balances
    calls, meta = [], []
    for tok_name, tok in (("acwETH", ACWETH), ("acstS", ACSTS)):
        for hname, h in HOLDERS.items():
            calls.append(("eth_call", [{"to": tok, "data": SEL_BAL + pad_a(h)}, hex(block)]))
            meta.append((tok_name, hname))
        calls.append(("eth_call", [{"to": tok, "data": "0x18160ddd"}, hex(block)]))
        meta.append((tok_name, "totalSupply"))
    res = batch(calls)
    for (tn, hn), v in zip(meta, res):
        out["extra_atokens"].setdefault(tn, {})[hn] = dec_u(v) if isinstance(v, str) else v

    # 2) proxy slots + admin()/implementation()
    for pname, p in PROXIES.items():
        rec = {}
        for slotname, slot in (("eip1967_impl", "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"),
                               ("eip1967_admin", "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103")):
            v = rpc("eth_getStorageAt", [p, slot, hex(block)])
            rec[slotname] = v
        for fn, sel in (("admin", "0xf851a440"), ("implementation", "0x5c60da1b")):
            v = rpc("eth_call", [{"to": p, "data": sel}, hex(block)])
            rec[fn] = v
        out["proxies"][pname] = rec

    # 3) rescueTokens(address,address,uint256) selector 0xcea9d26f probe
    #    call with amount=0 for token=USDC to=caller; simulate different senders
    for who in ("0x0000000000000000000000000000000000000001",
                "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
                "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F"):
        data = "0xcea9d26f" + pad_a("0x29219dd400f2Bf60E5a23d13Be72B486D4038894") + pad_a(who) + "0" * 64
        for pname in ("poolA", "poolB"):
            v = rpc("eth_call", [{"from": who, "to": PROXIES[pname], "data": data}, hex(block)])
            out["rescue_probe"][f"{pname}/from={who}"] = v

    with open(os.path.join(RAW, "extra_checks.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
