#!/usr/bin/env python3
"""Call view functions on Haiko contracts (read-only)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, call, block_number, selector_from_name  # noqa

STRATEGY = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
SOLVER = "0x073cc79b07a02fe5dcd714903d62f9f3081e15aeb34e3725f44e495ecd88a5a1"
DISTRIBUTOR = "0x5eb02e164f78fd91b9be6a0b9b3aa02c936db485bd760730f65711533c70a26"
QUOTER = "0x5860f2d7c1efc21e27fdeb1716a806c7604770603d1c5f161e473231eb261dc"

STRATEGY_VIEWS = [
    "market_manager", "name", "symbol", "version", "placed_positions", "queued_positions",
    "owner", "queued_owner", "strategy_owner", "queued_strategy_owner", "oracle",
    "oracle_summary", "strategy_params", "strategy_state", "is_paused", "bid", "ask",
    "base_reserves", "quote_reserves", "total_deposits", "withdraw_fee_rate", "withdraw_fees",
    "get_oracle_price", "get_balances", "get_balances_array", "get_bid_ask",
]
STRATEGY_VIEWS_ARG = ["is_whitelisted", "user_deposits", "get_user_balances"]

MM_VIEWS = ["owner", "base_token", "quote_token", "width", "strategy", "fee_controller",
            "swap_fee_rate", "flash_loan_fee_rate", "name", "symbol"]
SOLVER_VIEWS = ["market_params", "queued_market_params", "delay", "oracle", "get_oracle_price",
                "name", "symbol", "market_id", "vault_token_class", "owner", "queued_owner",
                "fees_per_share", "withdraw_fee_rate", "withdraw_fees", "get_virtual_positions"]
DIST_VIEWS = ["owner", "is_claimed"]

block = block_number()
out = {"block": block, "views": {}}


def do(addr, label, fn, calldata=None):
    sel = selector_from_name(fn)
    res = call(addr, sel, calldata or [])
    key = f"{label}.{fn}"
    if "result" in res:
        out["views"][key] = res["result"]
        print(f"{key} -> {res['result']}")
    else:
        out["views"][key] = {"error": res.get("error")}
        print(f"{key} -> ERR {res.get('error')}")


print("### ReplicatingStrategy", STRATEGY)
for fn in STRATEGY_VIEWS:
    do(STRATEGY, "strategy", fn)

print("### MarketManager", MM)
for fn in MM_VIEWS:
    do(MM, "mm", fn)

print("### ReplicatingSolver", SOLVER)
for fn in SOLVER_VIEWS:
    do(SOLVER, "solver", fn)

print("### Distributor", DISTRIBUTOR)
for fn in DIST_VIEWS:
    do(DISTRIBUTOR, "dist", fn)

with open(os.path.join(os.path.dirname(__file__), "views_initial.json"), "w") as f:
    json.dump(out, f, indent=1)
print("saved views_initial.json")
