#!/usr/bin/env python3
"""Inspect candidate contracts discovered from archived team-EOA page."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr, dec_addr, dec_uint

BLOCK = hexint(rpc("eth_blockNumber", []))
CANDS = {
    "nft_or_token_ce7a": "0xce7a099a7c5c062a4f66a6bbdec191a222baa3f2",
    "addminter_828b": "0x828b5adbe8e0a06aaf5d5a5fd16e6b15a393d86e",
    "contract_849b": "0x849b7b4541cde9cbe41cfd064d9d7ff459b9cea4",
    "contract_e207": "0xe207ea201a1ac5907e333c68e2ecd96fdb9389e1",
    "contract_3f48": "0x3f48b5d78afc94e5a5d33623d9903bbaf566ee35",
    "contract_d96c": "0xd96cca2e774e323bf22692865350aeb1af4200db",
    "contract_6abf": "0x6abfae833ca1a4e9a9d482dfeebcc5ecec635e90",
}
TEAM = "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5"
W507 = "0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9"

def decstr(r):
    if not r or r == "0x" or len(r) < 130: return None
    try:
        off = int(r[2:66], 16); ln = int(r[66+off*2:66+off*2+64], 16)
        return bytes.fromhex(r[66+off*2+64:66+off*2+64+ln*2]).decode("utf-8","replace")
    except Exception: return None

for name, a in CANDS.items():
    print("=====", name, a)
    cl = (len(rpc("eth_getCode", [a, "latest"]))-2)//2
    r = rpc_batch([
        ("eth_call", [{"to": a, "data": sel("name()")}, "latest"]),
        ("eth_call", [{"to": a, "data": sel("symbol()")}, "latest"]),
        ("eth_call", [{"to": a, "data": sel("totalSupply()")}, "latest"]),
        ("eth_call", [{"to": a, "data": sel("owner()")}, "latest"]),
        ("eth_call", [{"to": a, "data": sel("supportsInterface(bytes4)") + "80ac58cd".ljust(64,"0")}, "latest"]),
        ("eth_call", [{"to": a, "data": sel("supportsInterface(bytes4)") + "d9b67a26".ljust(64,"0")}, "latest"]),
        ("eth_call", [{"to": a, "data": sel("balanceOf(address)") + enc_addr(TEAM)}, "latest"]),
        ("eth_call", [{"to": a, "data": sel("balanceOf(address)") + enc_addr(W507)}, "latest"]),
        ("eth_getBalance", [a, "latest"]),
    ], timeout=90)
    print("  code_size:", cl)
    print("  name:", decstr(r[0]), "| symbol:", decstr(r[1]), "| totalSupply:", dec_uint(r[2]),
          "| owner:", dec_addr(r[3]))
    print("  ERC721:", dec_uint(r[4]), "ERC1155:", dec_uint(r[5]), "| teamBal:", dec_uint(r[6]), "507bBal:", dec_uint(r[7]), "| bnb:", hexint(r[8]))
