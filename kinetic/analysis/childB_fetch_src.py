#!/usr/bin/env python3
"""Child B: fetch verified sources for admin-side contracts from Flare Blockscout."""
import json, os, time
import requests

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://flare-explorer.flare.network/api/v2"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}
OUT = os.path.join(HERE, "childB-src")
os.makedirs(OUT, exist_ok=True)

CONTRACTS = {
    "UnitrollerTimelockUpgrader_8127": "0x81274d9250C8a36c62d3F45F18BD34D44D433b45",
    "UnitrollerTimelockUpgrader_5b8a": "0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC",
    "CErc20DelegatorTimelockUpgrader_fac3": "0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7",
    "TimelockController_58b1": "0x58b1b315319ce94fff3a665e2c4a7f61375aaba8",
    "ProtocolFTSOV2Oracle_c3": "0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D",
    "AllowList_59f6": "0x59f6559051c67bc3b2fe4b9275770eff6616e0b7",
    "FtsoV2Proxy_7bde": "0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20",
    "FtsoV2_impl_b18d": "0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32",
    "C1_admin_37c6": "0x37C6C7c719DB93085678cE72981CDd96219C9B72",
}

def get(url, params=None):
    for _ in range(3):
        try:
            r = requests.get(url, headers=HDR, params=params, timeout=40)
            if r.status_code == 200:
                return r.json()
        except Exception:
            pass
        time.sleep(1.5)
    return None

meta = {}
for name, a in CONTRACTS.items():
    js = get(f"{BASE}/smart-contracts/{a}")
    if js is None:
        print(name, "FETCH FAIL"); meta[name] = {"address": a, "error": "fetch"};
        continue
    src = js.get("source_code") or ""
    add = {c.get("file_path") or c.get("name"): c.get("source_code","") for c in (js.get("additional_sources") or [])}
    with open(os.path.join(OUT, f"{name}.sol"), "w") as f:
        f.write(src)
        for fn, sc in add.items():
            f.write(f"\n\n// ===== additional: {fn} =====\n")
            f.write(sc or "")
    meta[name] = {k: js.get(k) for k in ["name","language","compiler_version","verified_at","is_verified","abi","constructor_args","implementation_address","implementations"] if k in js}
    meta[name]["address"] = a
    meta[name]["files"] = [fn for fn in add]
    print(name, "=", js.get("name"), "| files:", len(add), "| primary len:", len(src))
    time.sleep(0.4)

with open(os.path.join(HERE, "childB-src-meta.json"), "w") as f:
    json.dump(meta, f, indent=2)
print("done")
