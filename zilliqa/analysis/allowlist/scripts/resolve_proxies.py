#!/usr/bin/env python3
"""Live resolution of proxy implementations/beacons/admins for allow-listed proxy contracts.

Read-only JSON-RPC against keyless https://api.zilliqa.com. Saves raw responses to raw/proxy_resolution.json.
"""
import json
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
RAW = HERE / "raw"
RPC = "https://api.zilliqa.com"
UA = {"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 (read-only research)"}

BEACON_SLOT = "0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50"
IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
ADMIN_SLOT = "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103"

BEACON_PROXIES_806 = [
    "0xD8b73cEd1B16C047048f2c5EA42233DA33168198",
    "0x6E08D3C40C8f46Ad8940576d798356763a235D58",
    "0x1519bc344682FE5ED24813ef57Ad6D5F3433cc2c",
    "0x3c8F552EaEc5c5e4eEe55203242AE6bbA09969EF",
]
BEACON_PROXY_759 = "0x06dA4573BB030f2eE2a5aC6Edbe81A6166Af0C78"
MINIMAL_PROXY_130 = "0x40b749DdD5cBeD3706289AD6AD99AE651c16dBE8"
EIP1967_PROXY = "0xE9df5b4b1134A3aadf693Db999786699B016239e"
CTOKEN_DELEGATOR = "0xB861959B443B8fb5a7179a97C136c7F5A9d00Df3"

out = {"rpc": RPC, "block": None, "reads": {}}


def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode()
    req = urllib.request.Request(RPC, data=body, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode())


def get_storage(addr, slot):
    return rpc("eth_getStorageAt", [addr, slot, "latest"])


def call(to, data, frm=None):
    obj = {"to": to, "data": data}
    if frm:
        obj["from"] = frm
    return rpc("eth_call", [obj, "latest"])


bn = int(rpc("eth_blockNumber", [])["result"], 16)
out["block"] = bn
print("head block", bn)

for addr in BEACON_PROXIES_806 + [BEACON_PROXY_759]:
    slot = get_storage(addr, BEACON_SLOT)["result"]
    beacon = "0x" + slot[-40:]
    impl = None
    r = call(beacon, "0x5c60da1b")
    if "result" in r and r["result"] != "0x":
        impl = "0x" + r["result"][-40:]
    out["reads"][addr] = {"kind": "beacon_proxy", "beacon_slot_raw": slot, "beacon": beacon,
                          "implementation_call": r, "implementation": impl}
    print(addr, "-> beacon", beacon, "-> impl", impl)
    time.sleep(0.15)

slot = get_storage(MINIMAL_PROXY_130, IMPL_SLOT)["result"]
impl = "0x" + slot[-40:]
adm = "0x" + get_storage(MINIMAL_PROXY_130, ADMIN_SLOT)["result"][-40:]
out["reads"][MINIMAL_PROXY_130] = {"kind": "eip1967_minimal_proxy", "impl_slot_raw": slot,
                                   "implementation": impl, "admin_slot": adm}
print(MINIMAL_PROXY_130, "-> impl", impl, "admin_slot", adm)
time.sleep(0.15)

for addr in [EIP1967_PROXY, CTOKEN_DELEGATOR]:
    entry = {"kind": "eip1967_upgradeable_proxy" if addr == EIP1967_PROXY else "ctoken_delegator",
             "calls": {}}
    for name, sel in [("admin()", "0xf851a440"), ("implementation()", "0x5c60da1b"),
                      ("pendingAdmin()", "0x26782247")]:
        entry["calls"][name] = call(addr, sel)
    entry["impl_slot_raw"] = get_storage(addr, IMPL_SLOT)["result"]
    entry["admin_slot_raw"] = get_storage(addr, ADMIN_SLOT)["result"]
    out["reads"][addr] = entry
    print(addr, json.dumps({k: v.get("result") for k, v in entry["calls"].items()}), entry["impl_slot_raw"][:20])
    time.sleep(0.15)

(RAW / "proxy_resolution.json").write_text(json.dumps(out, indent=1))
print("saved raw/proxy_resolution.json")
