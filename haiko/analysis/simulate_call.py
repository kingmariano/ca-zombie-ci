#!/usr/bin/env python3
"""Simulate a call from an account via starknet_simulateTransactions (read-only).

Usage: python3 simulate_call.py <sender> <to> <fn> <arg1> <arg2> ...
Builds a query invoke v1 with SKIP_VALIDATE, simulates, prints trace + events.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, selector_from_name, block_number  # noqa


def simulate(sender, to, fn, args, nonce="0x0"):
    sel = selector_from_name(fn)
    tx = {
        "type": "INVOKE",
        "sender_address": sender,
        "calldata": [hex(1), to, sel, hex(len(args))] + args,
        "signature": [],
        "nonce": nonce,
        "version": "0x3",
        "resource_bounds": {
            "l1_gas": {"max_amount": "0x200000", "max_price_per_unit": "0x20000000000"},
            "l2_gas": {"max_amount": "0x200000000", "max_price_per_unit": "0x20000000000"},
            "l1_data_gas": {"max_amount": "0x200000", "max_price_per_unit": "0x20000000000"},
        },
        "tip": "0x0",
        "paymaster_data": [],
        "account_deployment_data": [],
        "nonce_da_mode": "0x0",
        "fee_da_mode": "0x0",
    }
    r = rpc("starknet_simulateTransactions", {
        "block_id": "latest",
        "transactions": [tx],
        "simulation_flags": ["SKIP_VALIDATE"],
    })
    return r


if __name__ == "__main__":
    sender = sys.argv[1]
    to = sys.argv[2]
    fn = sys.argv[3]
    args = sys.argv[4:]
    print("block:", block_number())
    r = simulate(sender, to, fn, args)
    print(json.dumps(r, indent=1)[:6000])
