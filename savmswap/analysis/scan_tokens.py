#!/usr/bin/env python3
"""Scan tokens: bytecode mint selectors, owner(), simulation of public mint, promscan meta."""
import json, urllib.request, urllib.parse
from prom import *

TOKENS = {
    "gyro":    "0x05b86b7908e29bab68795fa9fdf52a78f3962d58",
    "FKS":     "0x0cc7e61842d09e8e7a0b1b177fe05c64d24d3d79",
    "Rkt":     "0xf1b75f4350793a81e68b9918e3d5b3c152644fb6",
    "BRUV":    "0x5092fcabec423c20622663433d3153bfadc3fbb4",
    "USTC":    "0x86d6af52e01e2258919f7e2ca19a2ddb51264334",
    "BEEBEE":  "0xa3fe7743ebe670965a1aa18ae62c5e006874e59c",
    "Rkt2":    "0xf7d0cd06c70f8a998a2ad844cce4b204abc1d334",
    "BAAI":    "0xe737b397fb87de91c0077b14be02fdaca06a2fb9",
    "CAT":     "0x65899e1d8802a468944035517e81d3e12e461611",
    "BOB":     "0xc7a17a1037de590ea1570c112ec42e85157d6c36",
    "ENS":     "0x" + "?",  # fill later
}

SELECTORS = {
    "mint(address,uint256)": "0x40c10f19",
    "mint(uint256)": "0xa0712d68",
    "mint()": "0x1249c58b",
    "mint(address)": "0x6a627842",
    "issue(uint256)": "0xcc872b66",
    "owner()": "0x8da5cb5b",
    "getOwner()": "0x893d20e8",
    "renounceOwnership()": "0x715018a6",
    "transferOwnership(address)": "0xf2fde38b",
}

ATTACKER = "0x1111111111111111111111111111111111111111"

def scan(tok):
    out = {"token": tok}
    try:
        code = rpc("eth_getCode", [tok, "latest"])
    except Exception as e:
        out["error"] = str(e); return out
    out["code_len"] = (len(code) - 2) // 2
    found = []
    for name, sel in SELECTORS.items():
        if sel[2:] in code.lower():
            found.append(name)
    out["selectors_present"] = found
    # owner attempts
    for sig, sel in [("owner()", "0x8da5cb5b"), ("getOwner()", "0x893d20e8")]:
        try:
            r = call(tok, sel)
            if r and r != "0x" and int(r, 16) != 0:
                out[sig] = dec_addr(r)
        except Exception:
            pass
    # basic ERC20 meta
    try:
        out["symbol"] = call_str(tok, "symbol()")
        out["name"] = call_str(tok, "name()")
        out["decimals"] = call_uint(tok, "decimals()")
        out["totalSupply"] = call_uint(tok, "totalSupply()")
    except Exception as e:
        out["meta_err"] = str(e)
    # simulate mint(address,uint256) from attacker
    for sig, sel, data in [
        ("mint(attacker,1e18)", "0x40c10f19", "0x40c10f19" + enc_addr(ATTACKER) + enc_uint(10**18)),
        ("mint(1e18)", "0xa0712d68", "0xa0712d68" + enc_uint(10**18)),
    ]:
        try:
            r = rpc("eth_call", [{"from": ATTACKER, "to": tok, "data": data}, "latest"])
            out["sim_" + sig] = "SUCCESS" if r is not None else "null"
        except Exception as e:
            msg = str(e)
            out["sim_" + sig] = "revert"
    return out

if __name__ == "__main__":
    res = {}
    for k, v in TOKENS.items():
        if v.endswith("?"):
            continue
        res[k] = scan(v)
        r = res[k]
        print(k, v, "code", r.get("code_len"), "| sel:", r.get("selectors_present"), "| owner:", r.get("owner()") or r.get("getOwner()"),
              "| sym", r.get("symbol"), "| sim40c10f19", r.get("sim_mint(attacker,1e18)", ""), "| sim a0712d68", r.get("sim_mint(1e18)", ""))
    json.dump(res, open("/home/heisenberg/CA/savmswap/analysis/token_scan.json", "w"), indent=1)
