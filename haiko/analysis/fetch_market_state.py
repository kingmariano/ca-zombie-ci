#!/usr/bin/env python3
"""Fetch per-market state for the 6 ReplicatingStrategy markets."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, call, block_number, selector_from_name  # noqa

S = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"

MARKETS = [
    "0x6812a18046f6b1d926ce6d081ceee71cb0ec7fbdb38167cc07d618ee8f5713e",
    "0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2",
    "0xeb87f342e5267cb250240851fdeaa111ce548934e529c41137fea49ccebdf",
    "0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b",
    "0x3ddeeae1e54ed0b70d57e067fa696ef333e69cc6dbe8b4469ad0e9900546b54",
    "0x16707e0f13b27d91c357a8294b28ff023e30acbf1456e5391f61fa22cdb0d76",
]


def felt(x):
    return int(x, 16) if isinstance(x, str) and x.startswith("0x") else int(x)


def u256(a):
    return felt(a[0]) + (felt(a[1]) << 128)


def do(addr, fn, calldata):
    sel = selector_from_name(fn)
    r = call(addr, sel, calldata)
    if "result" in r:
        return r["result"]
    return {"__error": r.get("error")}


out = {"block": block_number(), "markets": {}}
for m in MARKETS:
    e = {}
    e["strategy_params"] = do(S, "strategy_params", [m])
    e["strategy_state"] = do(S, "strategy_state", [m])
    e["total_deposits"] = do(S, "total_deposits", [m])
    e["strategy_owner"] = do(S, "strategy_owner", [m])
    e["withdraw_fee_rate"] = do(S, "withdraw_fee_rate", [m])
    e["is_paused"] = do(S, "is_paused", [m])
    e["get_balances"] = do(S, "get_balances", [m])
    e["get_oracle_price"] = do(S, "get_oracle_price", [m])
    e["market_info"] = do(MM, "market_info", [m])
    e["market_state"] = do(MM, "market_state", [m])
    e["market_configs"] = do(MM, "market_configs", [m])
    e["is_market_whitelisted"] = do(MM, "is_market_whitelisted", [m])
    e["width"] = do(MM, "width", [m])
    e["swap_fee_rate"] = do(MM, "swap_fee_rate", [m])
    e["liquidity"] = do(MM, "liquidity", [m])
    e["curr_limit"] = do(MM, "curr_limit", [m])
    out["markets"][m] = e
    print("=" * 30)
    print("market", m)
    for k, v in e.items():
        print(f"  {k}: {v}")

with open(os.path.join(os.path.dirname(__file__), "markets_state.json"), "w") as f:
    json.dump(out, f, indent=1)
print("saved markets_state.json")
