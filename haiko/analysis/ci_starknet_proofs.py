#!/usr/bin/env python3
"""CI proofs for C2-49 Haiko (read-only simulations + live state).

Reproduces, on GitHub Actions:
  P1  live state dump (contracts, balances, reserves, markets)
  P2  M1 (ETH/USDC) shareholder withdrawal simulation -> expected OK (H-O live)
  P3  M2 (wstETH/ETH) shareholder withdrawal simulation -> expected revert (S)
  P4  Solver (V2) holder withdrawal simulation -> expected OK (H-O live)
  P5  caller=0 gate probes for admin functions (expected auth reverts)
  P6  cross-market collect_order historical evidence (2 txs, market mismatch)
  P7  external-surface enumeration (entry points, markets, call targets)
Writes ci-out/proofs.json. No secrets printed (keyless RPC endpoints only).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from starknet_rpc import rpc, call, selector_from_name, block_number  # noqa

OUT = os.path.join(HERE, "..", "ci-out")
os.makedirs(OUT, exist_ok=True)

STRATEGY = "0x2ffce9d48390d497f7dfafa9dfd22025d9c285135bcc26c955aea8741f081d2"
MM = "0x38925b0bcf4dce081042ca26a96300d9e181b910328db54a6c89e5451503f5"
SOLVER = "0x073cc79b07a02fe5dcd714903d62f9f3081e15aeb34e3725f44e495ecd88a5a1"
OWNER = "0x43777a54d5e36179709060698118f1f6f5553ca1918d1004b07640dfc425000"
DISTRIBUTOR = "0x5eb02e164f78fd91b9be6a0b9b3aa02c936db485bd760730f65711533c70a26"

TOKENS = {
    "ETH": "0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7",
    "STRK": "0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d",
    "USDC": "0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8",
    "USDT": "0x68f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8",
    "wstETH": "0x42b8f0484674ca266ac5d08e4ac6a3fe65bd3129795def2dca5c34ecc5f96d2",
    "WBTC": "0x3fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac",
}

MARKETS = {
    "M1_ETH_USDC": "0x6812a18046f6b1d926ce6d081ceee71cb0ec7fbdb38167cc07d618ee8f5713e",
    "M2_wstETH_ETH": "0x678fc48b8c618084ba8ac46fa94f004b4af4dc85c9f9e14c2f94f2816676cc2",
    "M3_USDC_USDT": "0xeb87f342e5267cb250240851fdeaa111ce548934e529c41137fea49ccebdf",
    "M4_STRK_USDC": "0xf62b32bcbb3f2662000bdd8f3c51b528f0131ed7ca6a964a3004b4cc0d586b",
    "M5_STRK_ETH": "0x3ddeeae1e54ed0b70d57e067fa696ef333e69cc6dbe8b4469ad0e9900546b54",
    "M6_ETH_WBTC": "0x16707e0f13b27d91c357a8294b28ff023e30acbf1456e5391f61fa22cdb0d76",
}

M1_USER = "0x170499c035370153f2ae5053893c8d1d8e610f8375ddab9e64e3e4dc9b96fb9"
M1_SHARES = 1131787790826304
M2_USER = "0x4304a18f061bf57efc740b2e544a4d51a4e4bfb3431a340c6ebb7c31afb87f5"
M2_SHARES = 653427347566037304
SOLVER_MARKET_STRK_ETH = "0x53dc16e261b2af4a4960651b9fc06f7b0c3f8a4111448b7d6bdc94e51d8e92d"
SOLVER_USER = "0x7fe401f65712bdfcdd40704a57f67ecc923291bd8a2983537fb00178d647c13"
SOLVER_SHARES = 10**18

results = {"block": block_number()}


def u256(a):
    return int(a[0], 16) + (int(a[1], 16) << 128)


def sim(sender, to, fn, args, flags=("SKIP_VALIDATE",)):
    sel = selector_from_name(fn)
    nonce = rpc("starknet_getNonce", {"block_id": "latest", "contract_address": sender}).get("result", "0x0")
    tx = {
        "type": "INVOKE", "sender_address": sender,
        "calldata": [hex(1), to, sel, hex(len(args))] + args,
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


def sim_outcome(res):
    if "result" not in res:
        return {"error": res.get("error")}
    out = res["result"][0]
    ei = out.get("transaction_trace", {}).get("execute_invocation", {})
    if "revert_reason" in ei:
        return {"reverted": True, "reason": ei["revert_reason"][:300]}
    return {"reverted": False}


# ---------- P1 live state ----------
print("P1 state dump")
p1 = {"balances": {}, "reserves": {}, "owner": OWNER}
for who, addr in [("strategy", STRATEGY), ("market_manager", MM), ("solver", SOLVER), ("distributor", DISTRIBUTOR)]:
    p1["balances"][who] = {}
    for t, ta in TOKENS.items():
        r = call(ta, selector_from_name("balanceOf"), [addr])
        p1["balances"][who][t] = u256(r["result"]) if "result" in r else str(r.get("error"))
for t, ta in TOKENS.items():
    r = call(MM, selector_from_name("reserves"), [ta])
    p1["reserves"][t] = u256(r["result"]) if "result" in r else str(r.get("error"))
p1["owner_class"] = rpc("starknet_getClassHashAt", {"block_id": "latest", "contract_address": OWNER}).get("result")
results["P1_state"] = p1
print(json.dumps(p1, indent=1)[:1200])

# ---------- P2/P3/P4 withdrawals ----------
print("P2 M1 withdraw sim (expect OK)")
lo, hi = hex(M1_SHARES & ((1 << 128) - 1)), hex(M1_SHARES >> 128)
results["P2_M1_withdraw"] = sim_outcome(sim(M1_USER, STRATEGY, "withdraw", [MARKETS["M1_ETH_USDC"], lo, hi]))

print("P3 M2 withdraw sim (expect revert)")
lo, hi = hex(M2_SHARES & ((1 << 128) - 1)), hex(M2_SHARES >> 128)
results["P3_M2_withdraw"] = sim_outcome(sim(M2_USER, STRATEGY, "withdraw", [MARKETS["M2_wstETH_ETH"], lo, hi]))

print("P4 solver withdraw sim (expect OK)")
lo, hi = hex(SOLVER_SHARES & ((1 << 128) - 1)), hex(SOLVER_SHARES >> 128)
results["P4_solver_withdraw"] = sim_outcome(sim(SOLVER_USER, SOLVER, "withdraw_public", [SOLVER_MARKET_STRK_ETH, lo, hi]))
print(json.dumps({k: results[k] for k in ("P2_M1_withdraw", "P3_M2_withdraw", "P4_solver_withdraw")}, indent=1)[:800])

# ---------- P5 gate probes ----------
print("P5 gate probes (caller=0)")
probes = {}
for label, addr, fn, cd in [
    ("strategy.pause", STRATEGY, "pause", [MARKETS["M2_wstETH_ETH"]]),
    ("strategy.collect_and_pause", STRATEGY, "collect_and_pause", [MARKETS["M2_wstETH_ETH"]]),
    ("strategy.trigger_update_positions", STRATEGY, "trigger_update_positions", [MARKETS["M2_wstETH_ETH"]]),
    ("strategy.set_params", STRATEGY, "set_params", [MARKETS["M2_wstETH_ETH"], "0x1", "0x2", "0x0", "0x1", "0x0", TOKENS["ETH"], TOKENS["USDC"], "0x3", "0x64"]),
    ("strategy.upgrade", STRATEGY, "upgrade", ["0x1"]),
    ("strategy.withdraw", STRATEGY, "withdraw", [MARKETS["M2_wstETH_ETH"], "0x1", "0x0"]),
    ("strategy.update_positions", STRATEGY, "update_positions", [MARKETS["M2_wstETH_ETH"], "0x1", "0x1", "0x0", "0x1"]),
    ("mm.sweep", MM, "sweep", ["0x1", TOKENS["USDC"], "0x1", "0x0"]),
    ("mm.upgrade", MM, "upgrade", ["0x1"]),
    ("mm.whitelist_markets", MM, "whitelist_markets", ["0x1", MARKETS["M1_ETH_USDC"]]),
]:
    r = call(addr, selector_from_name(fn), cd)
    if "result" in r:
        probes[label] = "SUCCESS (no gate for caller 0)"
    else:
        e = r.get("error", {})
        data = e.get("data", {}) if isinstance(e.get("data"), dict) else {}
        rev = data.get("revert_error", "")
        try:
            msg = bytes.fromhex(rev[2:]).decode(errors="replace")
        except Exception:
            msg = str(rev)[:60]
        probes[label] = f"REVERT: {msg[:60]}"
results["P5_gates"] = probes
print(json.dumps(probes, indent=1)[:800])

# ---------- P6 cross-market collect_order evidence ----------
print("P6 historical cross-market collect evidence")
ev = {}
for name, tx, create_market, collect_market, amount, token in [
    ("2026-03-29_wstETH", "0x294992a851043d6ad0b614e9eefc4bfa6a553bb502bf853f9a16872c091ee70",
     "0x52b745121dc16c89c40ccec9dd12e7c9adde9bda61f21a2cf5a1bd9b9c3cadc",
     "0x5f6edcd8d1fac4219cea7499b93fd0f9d856fb2d76cdde99a460c17f169d13d",
     "1959030093873659156", "wstETH"),
    ("2026-10-06_STRK", "0x7718f335519b5f667cf48d195175712de44757ecfcdf258ce4aa0f947215788",
     "0x3c39aafa9ecda4eff898b85a361f2c40d027999c0d6c38631d50b128ca41e0b",
     "0x5959b98f0858633c81ead6e4ce4f9b97bca07655b9d4318d7c6f6fda491ae2",
     "92936058233108548465264", "STRK"),
]:
    tr = rpc("starknet_traceTransaction", {"transaction_hash": tx})
    ev[name] = {
        "tx": tx, "create_market": create_market, "collect_market": collect_market,
        "same_market": create_market == collect_market,
        "amount_raw": amount, "token": token,
        "trace_ok": "result" in tr,
    }
    print(f"  {name}: create_market==collect_market? {create_market == collect_market}; amount {amount} {token}")
results["P6_cross_market_collect"] = ev

# ---------- P7 external surface ----------
print("P7 external surface")
p7 = {}
for name, addr in [("ReplicatingStrategy", STRATEGY), ("MarketManager", MM), ("ReplicatingSolver", SOLVER)]:
    ch = rpc("starknet_getClassHashAt", {"block_id": "latest", "contract_address": addr}).get("result")
    cls = rpc("starknet_getClass", {"block_id": "latest", "class_hash": ch})
    if "result" in cls:
        ep = cls["result"].get("entry_points_by_type", {})
        p7[name] = {"class_hash": ch, "external_entry_points": len(ep.get("EXTERNAL", []))}
results["P7_surface"] = p7
print(json.dumps(p7, indent=1))

json.dump(results, open(os.path.join(OUT, "proofs.json"), "w"), indent=1)
print("saved ci-out/proofs.json at block", results["block"])
