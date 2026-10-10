#!/usr/bin/env python3
"""Generic Starknet call simulator (query v3 + SKIP_VALIDATE).

Usage:
  python3 sim_lib.py withdraw <user> <market> <shares>
  python3 sim_lib.py deposit  <user> <market> <base> <quote>
  python3 sim_lib.py custom   <user> <to> <fn> [args...]
Prints decoded trace + events + state diff summary.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, selector_from_name, block_number  # noqa

STRATEGY = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"

# selector -> name map for trace decoding
NAMES = {}


def _add(n):
    s = selector_from_name(n)
    if s:
        NAMES[s] = n


for n in ["withdraw", "deposit", "deposit_initial", "update_positions", "collect_and_pause",
          "amounts_inside_position", "market_info", "market_state", "position", "transfer",
          "transferFrom", "transfer_from", "balanceOf", "balance_of", "approve", "swap",
          "collect_order", "modify_position", "create_order", "mint", "burn", "get_balances",
          "user_deposits", "total_deposits", "flush", "on_flash_loan", "__execute__", "claim"]:
    _add(n)


def sim(sender, calls, nonce=None, flags=("SKIP_VALIDATE",)):
    """calls: list of (to, fn, args). Returns raw RPC result."""
    cd = [hex(len(calls))]
    for to, fn, args in calls:
        cd += [to, selector_from_name(fn), hex(len(args))] + args
    if nonce is None:
        nonce = rpc("starknet_getNonce", {"block_id": "latest", "contract_address": sender}).get("result", "0x0")
    tx = {
        "type": "INVOKE", "sender_address": sender, "calldata": cd,
        "signature": [], "nonce": nonce, "version": "0x3",
        "resource_bounds": {
            "l1_gas": {"max_amount": "0x4000", "max_price_per_unit": "0x400000000000"},
            "l2_gas": {"max_amount": "0x1000000", "max_price_per_unit": "0x400000000"},
            "l1_data_gas": {"max_amount": "0x4000", "max_price_per_unit": "0x400000000000"},
        },
        "tip": "0x0", "paymaster_data": [], "account_deployment_data": [],
        "nonce_data_availability_mode": "L1", "fee_data_availability_mode": "L1",
    }
    return rpc("starknet_simulateTransactions", {
        "block_id": "latest", "transactions": [tx], "simulation_flags": list(flags)})


def walk(c, d=0, maxd=8):
    if d > maxd:
        return
    sel = c.get("entry_point_selector") or ""
    name = NAMES.get(sel, sel[:24])
    print("  " * d + f"{c.get('contract_address','')[:14]} {name} {c.get('call_type')} "
          f"args={[x for x in c.get('calldata',[])[:6]]} -> {[x for x in (c.get('result') or [])[:6]]}")
    for ch in c.get("calls", []) or []:
        walk(ch, d + 1, maxd)


def evs(c):
    o = []
    for e in c.get("events", []) or []:
        o.append(e)
    for ch in c.get("calls", []) or []:
        o += evs(ch)
    return o


def show(res, save=None):
    if "result" not in res:
        print("SIM RPC ERR:", json.dumps(res)[:900])
        return None
    out = res["result"][0]
    if save:
        json.dump(out, open(save, "w"), indent=1)
    tr = out.get("transaction_trace", {})
    ei = tr.get("execute_invocation", {})
    if "revert_reason" in ei:
        print("REVERT:", ei["revert_reason"])
        return out
    print("EXECUTION OK")
    walk(ei)
    for e in evs(ei)[-10:]:
        print("   EV", (e.get("keys") or [None])[0], "keys:", e.get("keys", [])[1:4], "data:", e.get("data", [])[:8])
    return out


def u256(v):
    return int(v, 16) if isinstance(v, str) else v


if __name__ == "__main__":
    mode = sys.argv[1]
    print("block:", block_number())
    if mode == "withdraw":
        user, market, shares = sys.argv[2], sys.argv[3], int(sys.argv[4])
        lo, hi = hex(shares & ((1 << 128) - 1)), hex(shares >> 128)
        show(sim(user, [(STRATEGY, "withdraw", [market, lo, hi])]))
    elif mode == "deposit":
        user, market = sys.argv[2], sys.argv[3]
        base, quote = int(sys.argv[4]), int(sys.argv[5])
        bl, bh = hex(base & ((1 << 128) - 1)), hex(base >> 128)
        ql, qh = hex(quote & ((1 << 128) - 1)), hex(quote >> 128)
        show(sim(user, [(STRATEGY, "deposit", [market, bl, bh, ql, qh])]))
    elif mode == "custom":
        user, to, fn = sys.argv[2], sys.argv[3], sys.argv[4]
        show(sim(user, [(to, fn, sys.argv[5:])]))
