#!/usr/bin/env python3
"""Targeted gate probes for the Mode-A ionLBTC cToken + FeeDistributor authority."""
import json
import os
import sys

from rpc import RPC

MODE = os.environ.get("DRPC_API_KEY") and f"https://lb.drpc.org/ogrpc?network=mode&dkey={os.environ['DRPC_API_KEY']}" or "https://mainnet.mode.network"
CT = "0xADE794534c05F79981337E73dc2A987cdFf1958d"
FD = "0x8ea3fc79D9E463464C5159578d38870b770f6E57"
COMP = "0xfb3323e24743caf4add0fdccfb268565c0685556"
ATT = "0x000000000000000000000000000000000000dEaD"

r = RPC(MODE, batch_size=3)
block = r.block_number()
out = {"block": block}
LATEST = "latest"

# storage slots
for name, slot in [("ionicAdmin", 0), ("initialExchangeRateMantissa", 7), ("underlying", 21), ("ap", 22), ("_notEntered", 1)]:
    try:
        import requests
        resp = requests.post(
            MODE,
            json={"jsonrpc": "2.0", "id": 1, "method": "eth_getStorageAt", "params": [CT, hex(slot), LATEST]},
            timeout=60,
        ).json()
        out[f"slot_{name}"] = resp.get("result")
    except Exception as e:  # noqa: BLE001
        out[f"slot_{name}"] = f"ERR {e}"

# canCall probes
calls = []
meta = []
for sel, label in [
    ("0x3c3b4b89", "flash"),
    ("0xa0712d68", "mint"),
    ("0xdb006a75", "redeem"),
    ("0x852a12e3", "redeemUnderlying"),
    ("0xc5ebeaec", "borrow"),
    ("0x23b872dd", "transferFrom"),
    ("0xa9059cbb", "transfer"),
    ("0xf5e3c462", "liquidateBorrow"),
    ("0x0e752702", "repayBorrow"),
    ("0xb2a02ff1", "seize"),
]:
    calls.append((FD, r.encode_call("canCall(address,address,address,bytes4)(bool)", [COMP, ATT, CT, bytes.fromhex(sel[2:])])))
    meta.append(label)
res = r.eth_call_batch(calls, LATEST)
out["canCall_attacker"] = {}
for label, (st, val) in zip(meta, res):
    out["canCall_attacker"][label] = ("OK:" + val if st == "ok" else "ERR:" + val)

# simulate flash(1,0x) from attacker; capture revert data
data = r.encode_call("flash(uint256,bytes)", [1, b""])
import requests

resp = requests.post(
    MODE,
    json={
        "jsonrpc": "2.0",
        "id": 1,
        "method": "eth_call",
        "params": [{"from": ATT, "to": CT, "data": data}, LATEST],
    },
    timeout=60,
).json()
out["flash_sim"] = resp

# comptroller globals
specs = [
    (COMP, "oracle()(address)", []),
    (COMP, "admin()(address)", []),
    (COMP, "pauseGuardian()(address)", []),
    (COMP, "_mintGuardianPaused()(bool)", []),
    (COMP, "_borrowGuardianPaused()(bool)", []),
    (COMP, "transferGuardianPaused()(bool)", []),
    (COMP, "seizeGuardianPaused()(bool)", []),
    (COMP, "enforceWhitelist()(bool)", []),
    (COMP, "markets(address)(bool,uint256)", [CT]),
    (COMP, "mintGuardianPaused(address)(bool)", [CT]),
    (COMP, "borrowGuardianPaused(address)(bool)", [CT]),
    (COMP, "collateralFactorMantissa(address)(uint256)", [CT]),
    (COMP, "isDeprecated(address)(bool)", [CT]),
    (COMP, "whitelist(address)(bool)", [ATT]),
    (COMP, "suppliers(address)(bool)", [ATT]),
]
vals = r.read_many(specs, LATEST)
out["comptroller"] = {s[1].split("(")[0]: v for s, v in zip(specs, vals)}

# AddressesProvider
ap = out.get("slot_ap")
if ap and ap != "0x" + "0" * 64:
    ap_addr = "0x" + ap[-40:]
    out["ap_address"] = ap_addr
    for key in ["HYPERNATIVE_ORACLE", "IONIC_ORACLE", "PRICE_ORACLE"]:
        try:
            v = r.read(ap_addr, "getAddress(string)(address)", [key])
            out[f"ap_{key}"] = v
        except Exception as e:  # noqa: BLE001
            out[f"ap_{key}"] = f"ERR {e}"

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "gate_probe.json"), "w") as f:
    json.dump(out, f, indent=1, default=str)
print(json.dumps(out, indent=1, default=str))
