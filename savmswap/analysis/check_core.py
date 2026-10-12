#!/usr/bin/env python3
"""Deep-check core tokens (WPROM/USDT/USDC) and factory admin gating."""
import json, urllib.request
from prom import *

ATTACKER = "0x1234567890AbcdEF1234567890aBcdef12345678"
FACTORY = "0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9"

SELS = {
    "mint(address,uint256)": "0x40c10f19",
    "mint(uint256)": "0xa0712d68",
    "mint(address)": "0x6a627842",
    "mint()": "0x1249c58b",
    "mint(address,uint256,bool)": "0xc6c3b03b" if False else None,
    "deposit()": "0xd0e30db0",
    "withdraw(uint256)": "0x2e1a7d4d",
    "owner()": "0x8da5cb5b",
    "setFeeTo(address)": "0xf46901ed",
    "setFeeToSetter(address)": "0xa2e74af6",
    "setMigrator(address)": "0x4dd5b6a3" if False else None,
    "skim(address)": "0xbc25cf77",
    "sync()": "0xfff6cae9",
    "transferOwnership(address)": "0xf2fde38b",
}

def promscan(path):
    req = urllib.request.Request("https://promscan.io" + path, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def check_token(addr, label):
    print(f"===== {label} {addr}")
    code = rpc("eth_getCode", [addr, "latest"])
    clen = (len(code) - 2) // 2
    print("  code_len", clen)
    for name, sel in SELS.items():
        if sel and sel[2:].lower() in code.lower():
            print("  selector present:", name)
    for sig, sel in [("owner()", SELS["owner()"])]:
        try:
            r = call(addr, sel)
            if r and r != "0x" and int(r, 16) != 0:
                print("  owner ->", dec_addr(r))
            else:
                print("  owner -> zero/empty")
        except Exception as e:
            print("  owner() reverted")
    # simulate mints from attacker
    for sig, data in [
        ("mint(attacker,1e18)", "0x40c10f19" + enc_addr(ATTACKER) + enc_uint(10**18)),
        ("mint(1e18)", "0xa0712d68" + enc_uint(10**18)),
        ("mint()", "0x1249c58b"),
    ]:
        try:
            r = rpc("eth_call", [{"from": ATTACKER, "to": addr, "data": data}, "latest"])
            print("  sim", sig, "-> SUCCESS (!!!):", (r or "")[:66])
        except Exception as e:
            print("  sim", sig, "-> revert")
    # promscan meta
    try:
        d = promscan(f"/api/v2/tokens/{addr}")
        print("  meta:", {k: d.get(k) for k in ["name","symbol","decimals","total_supply","holders_count"]})
    except Exception as e:
        print("  meta err", e)
    try:
        d = promscan(f"/api/v2/smart-contracts/{addr}")
        sc = d.get("source_code") or ""
        print("  verified:", d.get("is_verified"), "file:", d.get("file_path"), "srclen", len(sc))
        if sc:
            open(f"/home/heisenberg/CA/savmswap/analysis/src_{label}.sol", "w").write(sc)
    except Exception as e:
        print("  src err", e)

if __name__ == "__main__":
    for addr, label in [
        ("0x04a21a38d5e275d6023b27504beb3095dc43b0c0", "WPROM"),
        ("0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed", "USDT"),
        ("0x5f1fe642f4d15f1b2bb8b1b7d3d13b56b1a6fbf4", "UNKNOWN-skip"),
    ]:
        if "skip" in label:
            continue
        check_token(addr, label)
    # factory gating
    print("===== FACTORY gating")
    for sig, data in [
        ("setFeeTo(attacker)", "0xf46901ed" + enc_addr(ATTACKER)),
        ("setFeeToSetter(attacker)", "0xa2e74af6" + enc_addr(ATTACKER)),
    ]:
        try:
            r = rpc("eth_call", [{"from": ATTACKER, "to": FACTORY, "data": data}, "latest"])
            print("  sim", sig, "-> SUCCESS (!!!)")
        except Exception as e:
            print("  sim", sig, "-> revert(ok)")
