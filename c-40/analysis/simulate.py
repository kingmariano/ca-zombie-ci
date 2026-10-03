#!/usr/bin/env python3
"""Impersonated simulation via starknet_simulateTransactions (SKIP_VALIDATE, read-only).
Uses a deployed account contract as sender; calls go through its __execute__."""
import sys, json; sys.path.insert(0, '.')
from sn import rpc, sn_keccak

CM = "0x073f6addc9339de9822cab4dac8c9431779c09077f02ba7bc36904ea342dd9eb"

def build_calldata(calls):
    """calls: list of (to, selector_name, [args])"""
    cd = [hex(len(calls))]
    for to, sel, args in calls:
        cd += [to, hex(sn_keccak(sel)), hex(len(args))] + [hex(a) if isinstance(a, int) else a for a in args]
    return cd

def sim(sender, calls, block="latest", flags=("SKIP_VALIDATE", "SKIP_FEE_CHARGE")):
    nonce = rpc("starknet_getNonce", [block, sender])
    nonce_hex = nonce.get("result", "0x0")
    tx = {
        "type": "INVOKE", "version": "0x3", "sender_address": sender,
        "calldata": build_calldata(calls), "signature": [], "nonce": nonce_hex,
        "resource_bounds": {
            "l1_gas": {"max_amount": "0x186a0", "max_price_per_unit": "0x5f5e100"},
            "l2_gas": {"max_amount": "0x186a0", "max_price_per_unit": "0x5f5e100"},
            "l1_data_gas": {"max_amount": "0x186a0", "max_price_per_unit": "0x5f5e100"},
        },
        "tip": "0x0", "paymaster_data": [], "account_deployment_data": [],
        "nonce_data_availability_mode": "L1", "fee_data_availability_mode": "L1",
    }
    return rpc("starknet_simulateTransactions", [block, [tx], list(flags)])

def report(label, r):
    if "result" in r:
        t = r["result"][0]["transaction_trace"]
        ex = t.get("execute_invocation", {})
        if "revert_reason" in ex:
            print(f"{label}: REVERT {ex['revert_reason'][:600]}")
        else:
            print(f"{label}: SUCCESS")
        return
    e = r.get("error", {})
    d = e.get("data", {})
    if isinstance(d, dict) and "revert_error" in d:
        rev = d["revert_error"]
        try: msg = bytes.fromhex(rev[2:]).decode("ascii", "replace")
        except Exception: msg = ""
        print(f"{label}: ERR {e.get('message')} | {msg}")
    else:
        print(f"{label}: ERR {json.dumps(e)[:400]}")

if __name__ == "__main__":
    ATT = "0x06d48ef7ab62c26e3ef1987c322096cd508e9034c82048783a6b438fc1344bc3"
    report("is_paused via attacker acct", sim(ATT, [(CM, "is_paused", [])]))
    report("owner via attacker acct", sim(ATT, [(CM, "owner", [])]))
