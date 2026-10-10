#!/usr/bin/env python3
"""Probe external functions via starknet_call (caller = 0) to test gates.

For each function, we pass plausible arguments. Outcomes:
- revert with auth-ish message -> gated
- revert with other message -> gate passed, failed elsewhere (callable-ish)
- success -> callable by caller 0 (unprivileged!)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, call, selector_from_name, block_number  # noqa

S = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
M1 = "0x6812a18046f6b1d926ce6d081ceee71cb0ec7fbdb38167cc07d618ee8f5713e"  # ETH/USDC paused
M2 = "0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2"  # wstETH/ETH
M4 = "0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b"  # STRK/USDC
ETH = "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
USDC = "0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8"

# strategy calls: (fn, calldata)
strategy_calls = [
    ("pause", [M1]),
    ("unpause", [M1]),
    ("collect_and_pause", [M2]),
    ("trigger_update_positions", [M2]),
    ("update_positions", [M2, "0x1", "0x1", "0x0", "0x1"]),
    ("withdraw", [M2, "0x1", "0x0"]),
    ("deposit", [M2, "0x1", "0x0", "0x1", "0x0"]),
    ("deposit_initial", [M2, "0x1", "0x0", "0x1", "0x0"]),
    ("set_whitelist", ["0x1", "0x1"]),
    ("set_withdraw_fee", [M2, "0x1"]),
    ("change_oracle", [ETH, USDC]),
    ("transfer_owner", ["0x1"]),
    ("accept_owner", []),
    ("transfer_strategy_owner", [M2, "0x1"]),
    ("accept_strategy_owner", [M2]),
    ("upgrade", ["0x1"]),
    ("collect_withdraw_fees", ["0x1", USDC, "0x1", "0x0"]),
    ("set_params", [M2, "0x1", "0x2", "0x0", "0x1", "0x0", ETH, USDC, "0x3", "0x64"]),
    ("add_market", [M4, "0x1", ETH, USDC, "0x3", "0x64", "0x1", "0x2", "0x0", "0x1", "0x0"]),
]

mm_calls = [
    ("sweep", ["0x1", USDC, "0x1", "0x0"]),
    ("whitelist_markets", ["0x1", M1]),
    ("set_flash_loan_fee_rate", [USDC, "0x1"]),
    ("transfer_owner", ["0x1"]),
    ("accept_owner", []),
    ("upgrade", ["0x1"]),
    ("create_market", [ETH, USDC, "0x1", "0x0", "0x1", "0x0", "0x989680", "0x0", "0x0"]),
    ("modify_position", [M2, "0x7925172", "0x7925522", "0x1", "0x0"]),
    ("mint", [M2, "0x7925172", "0x7925522"]),
    ("flash_loan", [USDC, "0x1", "0x0"]),
    ("swap", [M1, "0x1", "0x1", "0x0", "0x1", "0x0"]),
    ("collect_order", [M1, "0x1"]),
]


def felt_str(h):
    try:
        b = bytes.fromhex(h[2:])
        return b.decode(errors="replace")
    except Exception:
        return ""


def probe(addr, label, fn, cd):
    sel = selector_from_name(fn)
    r = call(addr, sel, cd)
    if "result" in r:
        out = f"SUCCESS result={r['result']}"
    else:
        e = r.get("error", {})
        data = e.get("data", {})
        rev = data.get("revert_error", "") if isinstance(data, dict) else str(data)
        msg = felt_str(rev) if isinstance(rev, str) and rev.startswith("0x") else str(rev)
        out = f"REVERT {e.get('code')}: {msg[:80]}"
    print(f"{label}.{fn} -> {out}")
    return out


print("### block", block_number())
results = {}
for fn, cd in strategy_calls:
    results[f"strategy.{fn}"] = probe(S, "strategy", fn, cd)
for fn, cd in mm_calls:
    results[f"mm.{fn}"] = probe(MM, "mm", fn, cd)

with open(os.path.join(os.path.dirname(__file__), "gate_probe.json"), "w") as f:
    json.dump({"block": block_number(), "results": results}, f, indent=1)
print("saved gate_probe.json")
