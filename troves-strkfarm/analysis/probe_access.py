#!/usr/bin/env python3
"""Probe access control on the retired Troves/STRKFarm vaults via starknet_call.

starknet_call executes the function read-only with caller = 0x0 (unprivileged).
Success or revert message is captured. No state is changed, nothing is signed.
"""
import json

from rpc import block_number, call, felt, selector

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
STRK = "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
ETH = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"

PROBES = {
    "withdraw_zklend(1,attacker)": ("withdraw_zklend", [hex(1), hex(0), felt(ATTACKER)]),
    "withdraw_zklend(1,zero)": ("withdraw_zklend", [hex(1), hex(0), felt("0x0")]),
    "claim_zklend(1,USDC,1)": ("claim_zklend", [hex(1), hex(0), felt(USDC), hex(1), hex(0)]),
    "claim_zklend(1,STRK,1)": ("claim_zklend", [hex(1), hex(0), felt(STRK), hex(1), hex(0)]),
    "set_batch_amount(1,USDC,1)": ("set_batch_amount", [hex(1), hex(0), felt(USDC), hex(1), hex(0)]),
    "transfer(0,1,attacker)": ("transfer", [felt("0x0"), hex(1), hex(0), felt(ATTACKER)]),
    "withdraw_nostra(attacker)": ("withdraw_nostra", [felt(ATTACKER)]),
    "pause()": ("pause", []),
    "upgrade(0x1)": ("upgrade", [hex(1)]),
    "set_settings()": ("set_settings", []),
    "register_zklend(empty)": ("register_zklend", []),
    "harvest()": ("harvest", []),
}


def probe(addr, entry, calldata):
    try:
        r = call(addr, selector(entry), calldata)
        return {"ok": True, "result": r}
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": str(e)[:220]}


def main():
    out = {"block": block_number(), "vaults": {}}
    for name, addr in VAULTS.items():
        v = {}
        for pname, (entry, cd) in PROBES.items():
            v[pname] = probe(addr, entry, cd)
        out["vaults"][name] = v
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
