#!/usr/bin/env python3
"""Deep state: positions, token balances, reserves for Haiko strategy markets."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from starknet_rpc import rpc, call, block_number, selector_from_name  # noqa

S = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"

TOKENS = {
    "ETH": "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "wstETH": "0x42b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "USDC": "0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x68f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "STRK": "0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "WBTC": "0x3fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
}

MARKETS = {
    "ETH/USDC": ("0x6812a18046f6b1d926ce6d081ceee71cb0ec7fbdb38167cc07d618ee8f5713e", "ETH", "USDC"),
    "wstETH/ETH": ("0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2", "wstETH", "ETH"),
    "USDC/USDT": ("0xeb87f342e5267cb250240851fdeaa111ce548934e529c41137fea49ccebdf", "USDC", "USDT"),
    "STRK/USDC": ("0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b", "STRK", "USDC"),
    "STRK/ETH": ("0x3ddeeae1e54ed0b70d57e067fa696ef333e69cc6dbe8b4469ad0e9900546b54", "STRK", "ETH"),
    "ETH/WBTC": ("0x16707e0f13b27d91c357a8294b28ff023e30acbf1456e5391f61fa22cdb0d76", "ETH", "WBTC"),
}


def felt(x):
    return int(x, 16) if isinstance(x, str) and x.startswith("0x") else int(x)


def u256(a):
    return felt(a[0]) + (felt(a[1]) << 128)


def do(addr, fn, calldata):
    sel = selector_from_name(fn)
    r = call(addr, sel, calldata)
    return r.get("result", {"__error": r.get("error")})


out = {"block": block_number()}

# 1) strategy + MM token balances
out["balances"] = {}
for who, addr in [("strategy", S), ("market_manager", MM)]:
    out["balances"][who] = {}
    for t, ta in TOKENS.items():
        r = do(ta, "balanceOf", [addr])
        out["balances"][who][t] = u256(r) if isinstance(r, list) and len(r) == 2 else r
        print(f"{who} {t}: {out['balances'][who][t]}")

# 2) MM reserves + donations per token
out["reserves"] = {}
for t, ta in TOKENS.items():
    r = do(MM, "reserves", [ta])
    d = do(MM, "donations", [ta])
    out["reserves"][t] = {"reserves": u256(r) if isinstance(r, list) and len(r) == 2 else r,
                          "donations": u256(d) if isinstance(d, list) and len(d) == 2 else d}
    print(f"MM reserves {t}: {out['reserves'][t]}")

# 3) positions: use bid/ask ranges from strategy_state
out["positions"] = {}
for mname, (mid, base, quote) in MARKETS.items():
    st = do(S, "strategy_state", [mid])
    if not isinstance(st, list) or len(st) < 10:
        out["positions"][mname] = {"error": st}
        continue
    bid_lo, bid_hi = felt(st[6]), felt(st[7])
    ask_lo, ask_hi = felt(st[8]), felt(st[9])
    e = {"bid": [bid_lo, bid_hi], "ask": [ask_lo, ask_hi]}
    for label, lo, hi in [("bid", bid_lo, bid_hi), ("ask", ask_lo, ask_hi)]:
        r = do(MM, "amounts_inside_position", [mid, S, hex(lo), hex(hi)])
        e[f"{label}_amounts"] = r
        print(f"{mname} {label} [{lo},{hi}]: {r}")
    out["positions"][mname] = e

with open(os.path.join(os.path.dirname(__file__), "deep_state.json"), "w") as f:
    json.dump(out, f, indent=1)
print("saved deep_state.json")
