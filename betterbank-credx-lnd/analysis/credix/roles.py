#!/usr/bin/env python3
"""CrediX role snapshot at one block. Read-only."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rpcx import rpc, batch  # noqa

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")

HASROLE = "0x91d14854"
GETROLEADMIN = "0x248a9ca3"

ROLES = {
    "DEFAULT_ADMIN": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "POOL_ADMIN": "0x12ad05bde78c5ab75238ce885307f96ecd482bb402ef831f99e7018a0f169b7b",
    "EMERGENCY_ADMIN": "0x5c91514091af31f62f596a314af7d5be40146b2f2355969392f055e12e0982fb",
    "RISK_ADMIN": "0x8aa855a911518ecfbe5bc3088c8f3dda7badf130faaf8ace33fdc33828e18167",
    "BRIDGE": "0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278",
    "ASSET_LISTING_ADMIN": "0x19c860a63258efbd0ecb7d55c626237bf5c2044c26c073390b74f0c13c857433",
    "FLASH_BORROWER": "0x939b8dfb57ecef2aea54a93a15e86768b9d4089f1ba61c245e6ec980695f4ca4",
}

ACLS = {
    "A_stability": "0x1637b78Dd5541F0dB2f3d04EeD39De37Df71BD08",
    "B_core": "0x8f0431F6Adb3e81D282d0508c16e2817DC95095b",
}

SUBJECTS = {
    "attacker": "0xF321683831Be16eeD74dfA58b02a37483cEC662e",
    "admin_0x0dd0": "0x0dd010513F7abB8F9c628dC164a24D953BCA09Cf",
    "zero": "0x0000000000000000000000000000000000000000",
    "aclAdmin_A": "0x3d0c177E035C30bb8681e5859EB98d114b48b935",
    "aclAdmin_B": "0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F",
    "poolA": "0x0850A9759165B25832E2cAa3dB3f2d04dc583D4E",
    "poolB": "0x56eb1bcB2aA011517fD7bf32641E79Bd8471770e",
    "configuratorA": "0x1C5D4B5DFC1A47e5Db839Cb8A0Fb36bAb1E986B7",
    "configuratorB": "0xc9122E191d9bDaBf9b59A31C01D4e6c4cd719E89",
    "address_zero_burn": "0x000000000000000000000000000000000000dEaD",
}


def pad(b):
    return b[2:].rjust(64, "0")


def pad_a(a):
    return a[2:].lower().rjust(64, "0")


def main():
    block = int(rpc("eth_blockNumber", []), 16)
    out = {"block": block, "acls": {}}
    for aname, acl in ACLS.items():
        entry = {"acl": acl, "roles": {}, "roleAdmins": {}}
        calls = []
        for rname, rh in ROLES.items():
            for sname, s in SUBJECTS.items():
                calls.append((rname, sname, rh, s))
            calls.append((rname, "__roleAdmin__", rh, None))
        payload = []
        for rname, sname, rh, s in calls:
            if sname == "__roleAdmin__":
                data = GETROLEADMIN + rh[2:]
            else:
                data = HASROLE + rh[2:] + pad_a(s)
            payload.append(("eth_call", [{"to": acl, "data": data}, hex(block)]))
        res = batch(payload)
        for (rname, sname, rh, s), v in zip(calls, res):
            if sname == "__roleAdmin__":
                entry["roleAdmins"][rname] = v if isinstance(v, str) else v
            else:
                entry["roles"].setdefault(rname, {})[sname] = (
                    int(v, 16) == 1 if isinstance(v, str) else v)
        out["acls"][aname] = entry
    with open(os.path.join(RAW, "roles.json"), "w") as f:
        json.dump(out, f, indent=1)
    for aname, e in out["acls"].items():
        print("===", aname, e["acl"], "===")
        for rname, subs in e["roles"].items():
            granted = [k for k, v in subs.items() if v is True]
            print(f"  {rname:<22} granted_to={granted or 'NONE'}")
        print("  roleAdmins:", {k: v for k, v in e["roleAdmins"].items()})


if __name__ == "__main__":
    main()
