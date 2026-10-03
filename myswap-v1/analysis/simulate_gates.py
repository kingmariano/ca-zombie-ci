#!/usr/bin/env python3
"""H-10 mySwap V1 — impersonated dry-runs (READ-ONLY simulations; nothing is sent).

Uses starknet_simulateTransactions with SKIP_VALIDATE + SKIP_FEE_CHARGE on the public
Cartridge RPC. Sender accounts are existing deployed accounts (impersonation is simulated only).

Proves for each candidate path whether an arbitrary caller reaches the target function and
whether it reverts on an access-control gate.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from starknet_nodep import rpc, sel, norm, block_number  # noqa

CORE = "0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28"
ADMIN = "0x1dec3416dc353a5b9fa9030016837df7226f2a8767b786fecd3566e8b57d3c8"
HACKER = "0x029f9de5cafb30f55e4a6f4f032e8774958520c1649b3a0441f1354c0b330518"
ATTACKER = HACKER  # a deployed account contract; only used as simulated sender
ETH = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
LP1 = "0x22b05f9396d2c48183f6deaf138a57522bcc8b35b67dee919f76403d1783136"
MERKLE = "0x005763f02381e89c6894ffea078d1cf9e58da0ead33d5b52aa608acc04063053"
CL = "0x1114c7103e12c2b2ecbd3a2472ba9c48ddcbf702b1c242dd570057e26212111"
EVIL = "0x028c9acd8eb7dc1cd7e3da98da3997cb57beca3c39d425e90780195df3a9a49e"
DAI = "0x00da114221cb83fa859dbdb4c44beeaa0bb37c7537ad5ae66fe5e0efd20e6eb3"

RPC = "https://api.cartridge.gg/x/starknet/mainnet"


def build_invoke(sender, calls, nonce="0x0", version="0x1"):
    """calls: list of (to, selector, calldata_list)."""
    cd = [hex(len(calls))]
    for to, selector, data in calls:
        cd += [to, selector, hex(len(data))] + data
    return {
        "type": "INVOKE",
        "version": version,
        "sender_address": sender,
        "calldata": cd,
        "signature": [],
        "nonce": nonce,
        "max_fee": "0x0",
    }


def simulate(tx, block="latest"):
    params = {
        "block_id": block,
        "transactions": [tx],
        "simulation_flags": ["SKIP_VALIDATE", "SKIP_FEE_CHARGE"],
    }
    try:
        return {"ok": True, "result": rpc("starknet_simulateTransactions", params, rpc_url=RPC)}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def ascii_frags(s):
    """Extract printable ASCII messages embedded as hex in a Starknet revert string."""
    out = []
    for m in re.finditer(r"0x([0-9a-fA-F]{6,})", s or ""):
        h = m.group(1)
        try:
            b = bytes.fromhex(h if len(h) % 2 == 0 else "0" + h)
            t = b.decode("ascii")
            if t.isprintable() and any(c.isalpha() for c in t):
                out.append(t)
        except Exception:
            pass
    return out


def trace_summary(sim):
    """Extract revert_reason / first call names from the simulation result."""
    if not sim["ok"]:
        return {"ok": False, "error": sim["error"][:1500]}
    res = sim["result"]
    out = {"ok": True, "entries": []}
    for entry in res:
        tr = entry.get("transaction_trace", {})
        ex = tr.get("execute_invocation", {})
        rr = ex.get("revert_reason")
        out["entries"].append({
            "revert_reason": rr,
            "inner_messages": ascii_frags(rr) if rr else [],
            "has_execute": "calls" in ex or "contract_address" in ex,
            "fee": entry.get("fee_estimation", {}).get("overall_fee"),
        })
    return out


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "ci-out", "simulate_gates.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    out = {"block": block_number(), "rpc": RPC, "read_only": True, "tests": {}}

    nonces = {}
    for who in (ATTACKER, ADMIN):
        try:
            nonces[who] = rpc("starknet_getNonce", {"block_id": "latest", "contract_address": norm(who)})
        except Exception as e:
            nonces[who] = "0x0"
            print("nonce err", who, str(e)[:100])
    print("nonces:", nonces)

    sel_upgrade = sel("upgrade")
    sel_dist = sel("distribute_tokens")
    sel_assert = sel("assert_admin")
    sel_mint = sel("mint")
    sel_burn_from = sel("burnFrom")
    sel_add_root = sel("add_root")
    sel_claim = sel("claim")
    sel_create_pool = sel("create_pool")

    tests = {
        # 1. attacker -> distribute_tokens (empty ledger): should revert at gate
        "attacker_distribute_tokens": build_invoke(ATTACKER, [(CORE, sel_dist, [ETH, "0x0"])]),
        # 2. attacker -> upgrade(0): should revert
        "attacker_upgrade": build_invoke(ATTACKER, [(CORE, sel_upgrade, ["0x1"])]),
        # 3. admin -> distribute_tokens(ETH, [(attacker, 1)]): should SUCCEED (P-only path)
        "admin_distribute_tokens": build_invoke(ADMIN, [(CORE, sel_dist, [ETH, "0x1", ATTACKER, "0x1", "0x0"])]),
        # 4. attacker -> LP token mint(attacker, 100): owner-gated
        "attacker_lp_mint": build_invoke(ATTACKER, [(LP1, sel_mint, [ATTACKER, "0x64", "0x0"])]),
        # 5. attacker -> LP token burnFrom(attacker, 100): owner-gated
        "attacker_lp_burnFrom": build_invoke(ATTACKER, [(LP1, sel_burn_from, [ATTACKER, "0x64", "0x0"])]),
        # 6. attacker -> Merkle add_root
        "attacker_merkle_add_root": build_invoke(ATTACKER, [(MERKLE, sel_add_root, ["0x123"])]),
        # 7. attacker -> Merkle claim(0, []) with empty proof
        "attacker_merkle_claim": build_invoke(ATTACKER, [(MERKLE, sel_claim, ["0x0", "0x0"])]),
        # 8. attacker -> CL create_pool(EVIL, DAI, 500): patched class gate test (3-arg ABI)
        "attacker_cl_create_pool_evil_dai": build_invoke(
            ATTACKER, [(CL, sel_create_pool, [EVIL, DAI, "0x1f4"])]),
        # 9. attacker -> CL create_pool(DAI, random, 500): arbitrary token admission gate
        "attacker_cl_create_pool_dai_random": build_invoke(
            ATTACKER, [(CL, sel_create_pool, [DAI, "0x1234", "0x1f4"])]),
    }

    for name, tx in tests.items():
        tx["nonce"] = nonces.get(tx["sender_address"], "0x0")
        sim = simulate(tx)
        summ = trace_summary(sim)
        out["tests"][name] = summ
        status = "OK/NO-REVERT" if summ.get("ok") and not summ["entries"][0].get("revert_reason") else "REVERT"
        inner = summ["entries"][0].get("inner_messages") if summ.get("ok") and summ.get("entries") else summ.get("error")
        print(f"{name:36s} {status:14s} {inner if inner else ''}")

    with open(out_path, "w") as f:
        json.dump(out, f, indent=1)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
