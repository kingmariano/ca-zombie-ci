#!/usr/bin/env python3
"""Child B: fetch Blockscout v2 info for key Kinetic admin/owner addresses."""
import json, os, time
import requests

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://flare-explorer.flare.network/api/v2"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

ADDRS = {
    "C1_oracle": "0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b",
    "C2_oracle": "0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c",
    "C3_oracle": "0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D",
    "C1_comptroller_unitroller": "0x15F69897E6aEBE0463401345543C26d1Fd994abB",
    "C2_comptroller_unitroller": "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8",
    "C1_admin_owner": "0x37C6C7c719DB93085678cE72981CDd96219C9B72",
    "C2_admin": "0x81274d9250C8a36c62d3F45F18BD34D44D433b45",
    "C2_oracle_owner": "0x58b1b315319ce94fff3a665e2c4a7f61375aaba8",
    "cToken_admin": "0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7",
    "upgrader_0x5b8A": "0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC",
    "kSFLR_delegator": "0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656",
    "kSFLR_impl": "0xf114620FFf7CAe11BE8A352E6dee25386547A333",
    "allowlist": "0x59f6559051c67bc3b2fe4b9275770eff6616e0b7",
    "ftso_proxy_0x7bde": "0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20",
    "ftso_impl_0xb18d": "0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32",
    "ftso_proxy_impl_slot": "0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20",
    "sFLR": "0x12e605bc104e93b45e1ad99f9e555f659051c2bb",
    "flrETH": "0x26a1fab310bd080542dc864647d05985360b16a5",
}

def get(url, params=None):
    for _ in range(3):
        try:
            r = requests.get(url, headers=HDR, params=params, timeout=40)
            if r.status_code == 200:
                return r.json()
            time.sleep(1.5)
        except Exception as e:
            err = str(e); time.sleep(1.5)
    return {"error": f"http {r.status_code}" if 'r' in dir() else err, "url": url}

out = {}
for name, a in ADDRS.items():
    if name == "ftso_proxy_impl_slot":
        continue
    info = get(f"{BASE}/addresses/{a}")
    # keep only what we need
    keys = ["hash","is_contract","name","ens_domain_name","metadata","is_verified","implementation",
            "implementations","proxy_type","is_scam","creator_address_hash","creation_transaction_hash",
            "has_tokens","token","public_tags","private_tags","watchlist_names","verified_at"]
    out[name] = {k: info.get(k) for k in keys if k in info} if isinstance(info, dict) else info
    if isinstance(info, dict):
        out[name]["_status"] = "ok"
    print(name, "->", json.dumps({k: out[name].get(k) for k in ["name","is_contract","is_verified","proxy_type","implementation"] if k in out[name]})[:300])

with open(os.path.join(HERE, "childB-blockscout.json"), "w") as f:
    json.dump(out, f, indent=2)
print("saved")
