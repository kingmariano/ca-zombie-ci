#!/usr/bin/env python3
"""Ecosystem recon: code sizes + balances of Narwhalswap-related addresses (read-only)."""
import sys, json, time
sys.path.insert(0, "/home/heisenberg/CA/narwhalswap/analysis")
from bsc import rpc, rpc_batch, SEL, words, word, b32_to_addr, hexint

CANDS = {
    "team_eoa":              "0xb104ae8b7da105ca79cba208b9a41c1d63fff2c5",
    "team_wallet_507b":      "0x507bdd06aca5facd19aa4b77037d3b9d48be2fb9",
    "power_strategy_v1":     "0xa1992a9777c3c11c466f44a4b9c7530719a22ea2",
    "narwhal_power":         "0x1d791eaa684a21de92618dedea7bf373e2486956",
    "collecter_feeTo":       "0x7f8a46ec48442d9ebf28fbc1144a83f8bc53f7e9",
    "farm_v2_1d22":          "0x1d227f7e283d653a60f94d2350cab7a49bb85c6f",
    "farm_v2_6da9":          "0x6da9ee0c0571b63e38950d1e12e835d5343f601b",
    "rnlp_6451":             "0x6451571cb5bee9fd575ad98506e96f3d09c66f91",
    "rnlp_1f7d":             "0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a",
    "nar_token":             "0xa1303e6199b319a891b79685f0537d289af1fc83",
    "thugs_token":           "0xe10e9822a5de22f8761919310dda35cd997d63c0",
    "lp_nar_wbnb":           "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
    "lp_wbnb_thugs":         "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
    "lp_wbnb_busd":          "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
    "factory":               "0xb9fa84912ff2383a617d8b433e926adf0dd3fea1",
    "wrapped_lpNAR_wbnb":    "0x00eda48b05a72e518033c78ad8c140109136fe23",
    "wrapped_lpTHUGS_wbnb":  "0x8b1bbfaf50551d8427bc24beecd3406cdcef48b8",
    "wrapped_lpBUSD_wbnb":   "0x6166911e31c55de58a32cd2abe379fe4382aec9d",
    "thugs_deployer":        "0x54af6dd5b2fe9d9e50ef56ebb7697b1ff05fd70c",
}
TOKENS = {
    "NAR":  "0xa1303e6199b319a891b79685f0537d289af1fc83",
    "WBNB": "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c",
    "BUSD": "0xe9e7cea3dedca5984780bafc599bd69add087d56",
    "THUGS": "0xe10e9822a5de22f8761919310dda35cd997d63c0",
    "LP_NARWBNB": "0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2",
    "LP_WBNBTHUGS": "0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957",
    "LP_WBNBBUSD": "0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3",
    "rNLP_6451": "0x6451571cb5bee9fd575ad98506e96f3d09c66f91",
    "rNLP_1f7d": "0x1f7d08d96d2520bd9196cb857e40d2a99e31de1a",
}

block = int(rpc("eth_blockNumber", []), 16)
print("block:", block)

calls = [("eth_getCode", [a, hex(block)]) for a in CANDS.values()]
calls += [("eth_getBalance", [a, hex(block)]) for a in CANDS.values()]
res = rpc_batch(calls, timeout=90)
n = len(CANDS)
out = {"block": block, "addresses": {}}
for i, (k, a) in enumerate(CANDS.items()):
    code = res[i] or "0x"
    bal = res[n + i]
    out["addresses"][k] = {"address": a, "code_size": (len(code) - 2) // 2,
                           "bnb_wei": str(hexint(bal) if bal else 0)}
    print(f"{k:22s} {a} codesize={(len(code)-2)//2:7d} bnb={(hexint(bal) if bal else 0)/1e18:.6f}")

# token balance matrix
bal_calls = []
keys = []
for tname, taddr in TOKENS.items():
    for cname, caddr in CANDS.items():
        bal_calls.append(("eth_call", [{"to": taddr, "data": SEL["balanceOf"] + word(caddr)}, hex(block)]))
        keys.append((tname, cname))
res2 = rpc_batch(bal_calls, timeout=120)
tb = {}
for (tname, cname), r in zip(keys, res2):
    v = hexint(r) if r else None
    if v:
        tb.setdefault(cname, {})[tname] = str(v)
out["token_balances_raw"] = tb
print("\n--- non-zero token balances (raw) ---")
for cname, d in sorted(tb.items()):
    for t, v in d.items():
        print(f"{cname:22s} {t:14s} {v}")

json.dump(out, open("/home/heisenberg/CA/narwhalswap/analysis/ecosystem/recon1_raw.json", "w"), indent=1)
print("\nsaved recon1_raw.json")
