#!/usr/bin/env python3
"""Batch read state of the Orbit/Silicon governance system (read-only)."""
import json, sys
from rpc import eth_call, rpc, SILICON, block_number

VOTING = "0x33fa9a4f2C06de9bD80A34663C72C797E257D3d9"
GOV = "0x3d0FD4bB3eA78657727eD7d20d9195288EaBC7dF"
ORC = "0x37908ffdEf18aDD36518e781a9a77C2C6f4A4260"
EXT = "0x68EAF006D3420887De399EB8BA5A531279e7F59C"
INF = "0xd4B19CaA9d2817930402FF60666d41377B411D9c"

def call(to, sel, arg=None, block="latest"):
    data = sel + (arg[2:].lower().rjust(64, "0") if arg else "")
    return eth_call(SILICON, to, data, block)

def u(h):
    return None if not h or h == "0x" else int(h, 16)

def addr(h):
    return None if not h or h == "0x" else "0x" + h[-40:]

def s(h):
    if not h or h == "0x": return None
    b = bytes.fromhex(h[2:])
    off = int.from_bytes(b[0:32], "big"); ln = int.from_bytes(b[off:off+32], "big")
    return b[off+32:off+32+ln].decode("utf-8", "replace")

if __name__ == "__main__":
    bn = block_number(SILICON)
    print("block", bn)
    print("== Voting static ==")
    for name, sel in [("totalStaking","0x165defa4"),("totalPending","0x3f90916a"),("lockupPeriod","0xee947a7c"),
                      ("minUnvotingAmount","0x41e68f6c"),("minVotingAmount","0x7c1ac4b8"),("registerCost","0x1871f761"),
                      ("maxDelegatedVoterCount","0x65aea2ca"),("extensionContract","0x24351da6"),("inflationContract","0xac00abf7"),
                      ("stakingToken","0x72f702f3"),("rewardToken","0xf7c618c1")]:
        r = call(VOTING, sel)
        v = u(r)
        if name.endswith("Contract") or name.endswith("Token"):
            v = addr(r)
        print(f"  {name:24}", v)
    print("== Governor static ==")
    for name, sel in [("admin_","0xa4baf750"),("owner_","0xe7663079"),("voting","0xfce1ccca"),("orc","0x0a0d8525"),
                      ("proposalCount","0xda35c664"),("proposalFee","0xc27cabb5"),("votingDelay","0x3932abb1"),
                      ("votingPeriod","0x02a251a3"),("quorumVotesRate","0x76769ee5"),("proposalThresholdRate","0x9c0784fd")]:
        r = call(GOV, sel)
        v = u(r)
        if name in ("admin_","owner_","voting","orc"):
            v = addr(r)
        print(f"  {name:24}", v)
    print("== ORC token ==")
    for name, sel in [("name","0x06fdde03"),("symbol","0x95d89b41"),("decimals","0x313ce567"),("totalSupply","0x18160ddd")]:
        r = call(ORC, sel)
        print(f"  {name:12}", s(r) if name in ("name","symbol") else u(r))
    print("== ORC balances ==")
    for holder, label in [(VOTING,"Voting"),(GOV,"Governor"),(EXT,"Extension"),(INF,"Inflation")]:
        print(f"  {label:12}", u(call(ORC, "0x70a08231", holder)))
    print("== ETH balances ==")
    for a, label in [(VOTING,"Voting"),(GOV,"Governor"),(EXT,"Extension"),(INF,"Inflation"),(ORC,"ORC token")]:
        print(f"  {label:12}", int(rpc(SILICON,"eth_getBalance",[a,"latest"])["result"],16)/1e18)
    print("== voterList ==")
    for i in range(12):
        a = addr(call(VOTING, "0x50e2e8af", hex(i)))
        if not a: break
        st = u(call(VOTING, "0x74363daa", a))
        pend = u(call(VOTING, "0x7571af22", a))
        vp = u(call(VOTING, "0xc07473f6", a))
        print(f"  [{i}] {a} staking={st} pending={pend} votingPower={vp}")
