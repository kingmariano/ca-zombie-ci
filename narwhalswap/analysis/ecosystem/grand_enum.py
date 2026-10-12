#!/usr/bin/env python3
"""Enumerate The Grand Banks farms: pools -> strategies -> contracts. Read-only."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_uint, dec_addr

TEAM = "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5"
DEV = "0x18527a351db2435fa21db88cbb87d4155188b62b0"
G1 = "0xd37ebaeb28c0a6c9a62d5c5c0119d464e28b367e"
G2 = "0xee814f5b2bf700d2e843dc56835d28d095161dd9"
F1 = "0x08f886b14af4fc75e49d6475f46d041f5f257ce1"  # GrandV1 owner
F2 = "0x3d8fd880976a3ea0f53cad02463867013d331107"  # GrandV2 owner
BLOCK = hexint(rpc("eth_blockNumber", []))

def c1(to, sig, args=""):
    r = dec_uint(rpc("eth_call", [{"to": to, "data": sel(sig) + args}, "latest"]))
    return r

def code_len(a):
    return (len(rpc("eth_getCode", [a, "latest"])) - 2) // 2

out = {"block": BLOCK, "farms": {}, "contracts": {}}
for label, farm in [("grand_v1_farm", F1), ("grand_v2_farm", F2)]:
    cl = code_len(farm)
    print(f"== {label} {farm} code_size={cl}")
    d = {"address": farm, "code_size": cl}
    out["contracts"][farm] = d
    if cl == 0:
        continue
    for sig in ["owner()", "poolLength()"]:
        try:
            v = c1(farm, sig)
            print("  ", sig, "=>", "0x%040x" % v if "owner" in sig else v)
            d[sig] = ("0x%040x" % v)[-40:].join(["0x", ""]) if "owner" in sig else v
            if "owner" in sig:
                d["owner"] = dec_addr("0x%064x" % v)
        except Exception as e:
            print("  ", sig, "ERR", str(e)[:100])
    pl = d.get("poolLength()") or 0
    pools = []
    for pid in range(pl):
        try:
            r = rpc("eth_call", [{"to": farm, "data": sel("poolInfo(uint256)") + enc_addr(hex(pid)[2:])}, "latest"])
            b = bytes.fromhex(r[2:])
            words = [b[i:i+32].hex() for i in range(0, len(b), 32)]
            want = dec_addr(words[0]); alloc = int(words[1], 16); strat = dec_addr(words[4])
            fryS = dec_addr(words[5]); fryL = dec_addr(words[6]); isLp = int(words[7], 16)
            pools.append({"pid": pid, "want": want, "alloc": alloc, "strat": strat,
                          "frySailing": fryS, "fryLanding": fryL, "isLp": isLp})
            print(f"   pool {pid}: want={want} alloc={alloc} strat={strat} sail={fryS} land={fryL} isLp={isLp}")
        except Exception as e:
            print("   pool", pid, "ERR", str(e)[:100])
    d["pools"] = pools
    out["farms"][label] = d

json.dump(out, open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/grand_enum.json", "w"), indent=1)
print("\nsaved grand_enum.json ; block", BLOCK)
