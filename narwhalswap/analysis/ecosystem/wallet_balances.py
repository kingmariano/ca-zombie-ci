#!/usr/bin/env python3
"""Balances of all team-related EOAs/wallets and key contracts (read-only)."""
import sys, json
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis/ecosystem")
from bsc import rpc, rpc_batch, hexint
from call_lib import sel, enc_addr

BLOCK = hexint(rpc("eth_blockNumber", []))
TOKENS = {
    "NAR": "0xa1303e6199b319a891b79685f0537d289af1fc83",
    "THUGS": "0xe10e9822a5de22f8761919310dda35cd997d63c0",
    "WBNB": "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",
    "BUSD": "0xe9e7cea3dedca5984780bafc599bd69add087d56",
    "USDT": "0x55d398326f99059ff775485246999027b3197955",
    "GRAND_V1": "0xd37ebaeb28c0a6c9a62d5c5c0119d464e28b367e",
    "CATO_GRANDV2": "0xee814f5b2bf700d2e843dc56835d28d095161dd9",
    "LP_NAR_WBNB": "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
    "LP_WBNB_THUGS": "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
    "LP_WBNB_BUSD": "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
}
WALLETS = {
    "team_eoa_b104": "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5",
    "team_wallet_507b": "0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9",
    "dev_18527a_grand": "0x18527a351db2435fa21db88cbb87d4155188b62b0",
    "dev2_ab3921_grand": "0xab3921c5de7e3459ce07f7015b3fdf0ebec927ef",
    "factory_deployer_c768": "0xc76827cce55338cbd6b399f45a75df0cd5da2749",
    "timelock_v1_d68415": "0xd68415507d4beb355aeec2f0d52938800c7b62e0",
    "thugs_initialdist_3009": "0x3009c9c09a467aaea1c8d8cd6ebd18bfb4339b9b",
    "thugs_burnres_00fd98": "0xfd98d6dedc7ed8556ba61dc7902799c9815a5722",
    "thugs_team_6e65": "0x6e65f24a9c7230c3bfbe90f39924ac8384f6152f",
    "thugs_dev_4e43": "0x4e43397417c6938f60b108650d832390dbd4c4fd",
    "thugs_mktg_481f": "0x481f0079bb59d8feb2426b6e08a2af01d7b49500",
    "thugs_deployer_54af": "0x54af6dd5b2fe9d9e50ef56ebb7697b1ff05fd70c",
    "collecter_7f8a": "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9",
    "grandbank_v1_08f8": "0x08f886b14af4fc75e49d6475f46d041f5f257ce1",
    "grandbank_v2_3d8f": "0x3d8fd880976a3ea0f53cad02463867013d331107",
}
calls = []
meta = []
for w, a in WALLETS.items():
    calls.append(("eth_getBalance", [a, hex(BLOCK)])); meta.append((w, "BNB"))
for w, a in WALLETS.items():
    for t, ta in TOKENS.items():
        calls.append(("eth_call", [{"to": ta, "data": sel("balanceOf(address)") + enc_addr(a)}, hex(BLOCK)])); meta.append((w, t))
res = rpc_batch(calls, timeout=180)
out = {}
for (w, t), r in zip(meta, res):
    v = hexint(r) if r else 0
    if v:
        out.setdefault(w, {})[t] = str(v)
print(json.dumps(out, indent=1))
json.dump({"block": BLOCK, "balances": out}, open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/wallet_balances.json", "w"), indent=1)
print("block", BLOCK)
