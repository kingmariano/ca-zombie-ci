#!/usr/bin/env python3
"""Read zkLend-recovery views for the 6 retired Troves/STRKFarm vaults."""
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

SEL = {n: selector(n) for n in [
    "get_zklend_amount", "zklend_position", "is_paused", "get_settings",
    "config", "get_all_shares", "get_total_unminted_shares", "health_factors",
    "get_nostra_info", "get_nostra_amount", "owner", "name", "symbol",
]}

PROBES = {
    "zero": "0x0",
    "vault_owner_AC": "0x3495dd1e4838aa06666aac236036d86e81a6553e222fc02e70c2cbc0062e8d0",
    "vault_owner_Sensei": "0x55d39827894c40f04fe3a314ad013bf9bc5220f7eb6cd8863212dcba6c0e16e",
    "random1": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd",
    "attacker": "0x0badc0de0badc0de0badc0de0badc0de0badc0de0badc0de0badc0de0badc0de",
}


def u256(hexstr):
    v = int(hexstr, 16)
    return f"{v & ((1 << 128) - 1)},{v >> 128}"


def try_call(to, entry, calldata=()):
    try:
        return call(to, SEL[entry], calldata)
    except Exception as e:  # noqa: BLE001
        return {"__error__": str(e)[:160]}


def main():
    out = {"block": block_number(), "vaults": {}}
    for name, addr in VAULTS.items():
        v = {}
        v["name"] = try_call(addr, "name")
        v["is_paused"] = try_call(addr, "is_paused")
        v["owner"] = try_call(addr, "owner")
        v["get_zklend_amount_b1"] = try_call(addr, "get_zklend_amount", [u256("0x1")])
        v["get_zklend_amount_b0"] = try_call(addr, "get_zklend_amount", [u256("0x0")])
        v["positions"] = {}
        for pname, paddr in PROBES.items():
            r = try_call(addr, "zklend_position", [felt(paddr), u256("0x1")])
            v["positions"][pname] = r
        # other views that only some classes have
        for entry in ["get_settings", "config", "get_all_shares", "get_total_unminted_shares", "health_factors", "get_nostra_info", "get_nostra_amount"]:
            r = try_call(addr, entry)
            if not (isinstance(r, dict) and "__error__" in r):
                v[entry] = r
        out["vaults"][name] = v
    print(json.dumps(out, indent=1))


if __name__ == "__main__":
    main()
