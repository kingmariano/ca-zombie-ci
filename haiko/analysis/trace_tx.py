#!/usr/bin/env python3
"""Decode a Starknet transaction trace into a readable call tree.

Usage: python3 trace_tx.py <tx_hash> [--max-depth N]
Reads class ABIs from analysis/classes to name selectors (best effort).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, selector_from_name  # noqa

CLASSES = os.path.join(os.path.dirname(__file__), "classes")

# Build selector->name map from saved class ABIs + common names
NAMES = {}


def add_name(n):
    s = selector_from_name(n)
    if s:
        NAMES.setdefault(s, n)


for fn in ["balanceOf", "balance_of", "transfer", "transferFrom", "transfer_from", "approve",
           "symbol", "name", "decimals", "totalSupply", "total_supply", "allowance",
           "__execute__", "__validate__", "execute", "execute_from_outside", "is_valid_signature",
           "owner", "owner_of", "token_uri", "supports_interface", "get_threshold", "get_signers",
           "swap", "multicall", "mint", "burn", "collect_order", "modify_position",
           "amounts_inside_position", "position", "limit_info", "market_info", "market_state",
           "update_positions", "trigger_update_positions", "deposit", "withdraw", "claim"]:
    add_name(fn)

for fn in os.listdir(CLASSES):
    if not fn.endswith(".json"):
        continue
    try:
        d = json.load(open(os.path.join(CLASSES, fn)))
        abi = json.loads(d["abi"])
        for e in abi:
            items = []
            if e.get("type") == "function":
                items = [e]
            elif e.get("type") == "interface":
                items = e.get("items", [])
            for f in items:
                if f.get("type") == "function":
                    add_name(f["name"])
    except Exception:
        pass


def short(x, n=18):
    return x[:n] + "…" if len(x) > n else x


def decode_call(call, depth=0, max_depth=8):
    sel = call.get("entry_point_selector", "")
    name = NAMES.get(sel, "")
    ca = call.get("contract_address", "")
    calldata = call.get("calldata", [])
    res = call.get("result", [])
    line = "  " * depth + f"{short(ca)} {name or sel} (call_type={call.get('call_type')})"
    line += f" calldata={[short(c) for c in calldata[:14]]}" + (" …" if len(calldata) > 14 else "")
    if res:
        line += f" result={[short(r) for r in res[:8]]}" + (" …" if len(res) > 8 else "")
    print(line)
    if depth < max_depth:
        for c in call.get("calls", []) or []:
            decode_call(c, depth + 1, max_depth)


if __name__ == "__main__":
    tx = sys.argv[1]
    md = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    r = rpc("starknet_traceTransaction", {"transaction_hash": tx})
    if "result" not in r:
        print("ERR:", json.dumps(r)[:400])
        sys.exit(1)
    tr = r["result"]
    print("== type:", tr.get("type"))
    for key in ["validate_invocation", "execute_invocation", "fee_transfer_invocation"]:
        if key in tr and tr[key]:
            print(f"--- {key}")
            if "calls" in tr[key]:
                decode_call(tr[key], 0, md)
            else:
                print("   ", tr[key].get("contract_address"), NAMES.get(tr[key].get("entry_point_selector"), tr[key].get("entry_point_selector")))
    if "function_invocation" in tr:
        print("--- function_invocation")
        decode_call(tr["function_invocation"], 0, md)
