#!/usr/bin/env python3
"""Extras: THUGS token timelock, NarCard/NarNft governance, myst getters, paused states."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint, keccakhex

BLOCK = hexint(rpc("eth_blockNumber", []))
THUGS = "0xe10e9822a5de22f8761919310dda35cd997d63c0"

def rlp_encode(item):
    if isinstance(item, int):
        if item == 0: return b'\x80'
        b = item.to_bytes((item.bit_length()+7)//8, 'big')
        if b[0] < 0x80 and len(b) == 1: return b
        return bytes([0x80 + len(b)]) + b
    if len(item) == 1 and item[0] < 0x80: return item
    if len(item) < 56: return bytes([0x80 + len(item)]) + item
    l = len(item).to_bytes((len(item).bit_length()+7)//8, 'big')
    return bytes([0xb7 + len(l)]) + l + item
def rlp_list(items):
    payload = b''.join(rlp_encode(i) for i in items)
    if len(payload) < 56: return bytes([0xc0 + len(payload)]) + payload
    l = len(payload).to_bytes((len(payload).bit_length()+7)//8, 'big')
    return bytes([0xf7 + len(l)]) + l + payload
tl = keccakhex(rlp_list([bytes.fromhex(THUGS[2:]), 1]))[-40:]
print("THUGS TokenTimelock (computed):", "0x" + tl)

# myst getters + NarCard governance + THUGS paused
MYST = "0xe207ea201a1ac5907e333c68e2ecd96fdb9389e1"
sigs = [("myst","nftToken()"),("myst","totalCards()"),("myst","funded()"),("myst","paused()"),("myst","owner()"),
        ("myst","userCount(address)"),("myst","cards(uint256)"),("myst","baseUrl()"),
        ("thugs","paused()"),("thugs","owner()"),("thugs","initialDistributionAddress()"),("thugs","burnReservesAddress()"),
        ("thugs","bscSwapPair()"),("thugs","whitelistedSenders(address)"),
        ("narcard","_governance()"),("narcard","_minters(address)"),("narcard","totalSupply()"),("narcard","baseURI()"),
        ("narnft","owner()"),("narnft","_minters(address)"),("narnft","totalSupply()"),("narnft","baseURI()"),("narnft","started()")]
ADDR = {"myst": MYST, "thugs": THUGS, "narcard": "0x828b5adbe8e0a06aaf5d5a5fd16e6b15a393d86e", "narnft": "0xce7a099a7c5c062a4f66a6bbdec191a222baa3f2"}
TEAM = "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5"
calls = []
for t, s in sigs:
    a = ADDR[t]
    data = sel(s)
    if s == "userCount(address)": data += enc_addr(TEAM)
    if s == "cards(uint256)": data += enc_addr("0")
    if s == "_minters(address)": data += enc_addr(TEAM)
    if s == "whitelistedSenders(address)": data += enc_addr("0x3009c9c09a467aaea1c8d8cd6ebd18bfb4339b9b")
    calls.append(("eth_call", [{"to": a, "data": data}, "latest"]))
rs = rpc_batch(calls, timeout=120)
for (t, s), r in zip(sigs, rs):
    v = r
    if s in ("owner()", "_governance()", "initialDistributionAddress()", "burnReservesAddress()", "bscSwapPair()", "nftToken()"):
        v = dec_addr(r)
    elif r and r != "0x": v = dec_uint(r)
    print(f"{t:8s} {s:24s} => {v}")
# timelock balance
rb = rpc_batch([("eth_call", [{"to": THUGS, "data": sel("balanceOf(address)") + enc_addr("0x" + tl)}, "latest"]),
                ("eth_getBalance", ["0x" + tl, "latest"]),
                ("eth_getCode", ["0x" + tl, "latest"])], timeout=60)
print("timelock THUGS balance:", (hexint(rb[0]) or 0)/1e18, "bnb:", hexint(rb[1])/1e18, "code:", (len(rb[2])-2)//2)
json.dump({"block": BLOCK, "thugs_timelock": "0x"+tl}, open("extras.json","w"), indent=1)
