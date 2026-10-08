#!/usr/bin/env python3
"""Child B batch 5: guardian identities, unitroller admin history, FTSO proxy upgrade history,
   allowlist contents, revert reasons for C3/C1 sims."""
import json, os, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]
BS = "https://flare-explorer.flare.network/api/v2"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

def rpc(method, params):
    for r in RPCS:
        try:
            js = requests.post(r, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=45).json()
            return js
        except Exception: pass
    return {}

def bs(path, params=None):
    for _ in range(3):
        try:
            r = requests.get(BS + path, headers=HDR, params=params, timeout=40)
            if r.status_code == 200: return r.json()
            time.sleep(1)
        except Exception: time.sleep(1)
    return None

def sel(sig): return keccak(text=sig)[:4].hex()
def enc(sig, atypes=None, avals=None):
    return "0x" + sel(sig) + (abi_encode(atypes or [], avals or []).hex() if atypes else "")

out = {}
RAND = "0x1111111111111111111111111111111111111111"

# guardian identities
for name, a in [("C1_pauseGuardian","0x5C37a9c61d7c9349b399EDc78f00AA90710b2B75"),
                ("C2_pauseGuardian","0x452b97fdcb1bcf333112bf7920a81161de29f41d"),
                ("C3_unitroller_admin","0x1e7d53bacf8be70a8db3f5cd968048d6c76b770d"),
                ("C3_unitroller_oracle","0x4d309754eb1ae09e94bfc2b5cb3178a317e76273")]:
    info = bs(f"/addresses/{a}") or {}
    code = rpc("eth_getCode", [a, "latest"]).get("result","0x")
    out[name] = {"name": info.get("name"), "is_verified": info.get("is_verified"),
                 "proxy_type": info.get("proxy_type"), "codesize": max(0,(len(code)-2)//2)}
    print(name, out[name])

# unitroller admin history (C2 + C1)
ev = {"NewAdmin": "0x" + keccak(text="NewAdmin(address,address)").hex(),
      "NewPendingAdmin": "0x" + keccak(text="NewPendingAdmin(address,address)").hex(),
      "NewImplementation": "0x" + keccak(text="NewImplementation(address,address)").hex(),
      "NewPendingImplementation": "0x" + keccak(text="NewPendingImplementation(address,address)").hex()}
out["unitroller_events"] = {}
for name, a in [("c2", "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8"), ("c1", "0x15F69897E6aEBE0463401345543C26d1Fd994abB")]:
    out["unitroller_events"][name] = {}
    for en, t0 in ev.items():
        js = bs(f"/addresses/{a}/logs", {"topic": t0}) or {}
        items = js.get("items", []) or []
        out["unitroller_events"][name][en] = [
            {"block": it.get("block_number"), "tx": it.get("transaction_hash"),
             "topics": it.get("topics"), "data": it.get("data")} for it in items]
        print(name, en, len(items))

# FTSO proxy Upgraded history
t_up = "0x" + keccak(text="Upgraded(address)").hex()
js = bs(f"/addresses/0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20/logs", {"topic": t_up}) or {}
out["ftso_proxy_upgraded"] = [{"block": it.get("block_number"), "topics": it.get("topics"),
                               "data": it.get("data")} for it in (js.get("items") or [])]
print("ftso proxy Upgraded events:", len(out["ftso_proxy_upgraded"]))

# allowlist contents
AL = "0x59f6559051c67bc3b2fe4b9275770eff6616e0b7"
ln = rpc("eth_call", [{"to": AL, "data": enc("allowedAddressesLength()")}, "latest"]).get("result")
out["allowlist_length"] = int(ln,16) if ln else None
entries = []
if out["allowlist_length"]:
    for i in range(min(out["allowlist_length"], 50)):
        h = rpc("eth_call", [{"to": AL, "data": enc("allowedAddresses(uint256)", ["uint256"], [i])}, "latest"]).get("result")
        if h: entries.append("0x" + h[-40:])
out["allowlist_entries"] = entries
print("allowlist length:", out["allowlist_length"], "entries:", entries[:10])

# revert reasons for C3 setTokenConfig / C1 unitroller sims
def call_from(to, sig, atypes, avals):
    return rpc("eth_call", [{"to": to, "from": RAND, "data": enc(sig, atypes, avals)}, "latest"])
out["c3_setTokenConfig_revert"] = call_from("0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D",
    "setTokenConfig((address,bytes21,uint64,address))", ["(address,bytes21,uint64,address)"],
    [("0xfbda5f676cb37624f28265a144a48b0d6e87d3b6", bytes.fromhex("01"+"00"*20), 420, "0x"+"00"*20)])
out["c1_unitroller_setPriceOracle"] = call_from("0x15F69897E6aEBE0463401345543C26d1Fd994abB", "_setPriceOracle(address)", ["address"], [RAND])
out["c1_unitroller_setCF"] = call_from("0x15F69897E6aEBE0463401345543C26d1Fd994abB", "_setCollateralFactor(address,uint256)", ["address","uint256"], ["0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656", 0])
out["c1_unitroller_setPendingAdmin"] = call_from("0x15F69897E6aEBE0463401345543C26d1Fd994abB", "_setPendingAdmin(address)", ["address"], [RAND])
out["c2_unitroller_setPendingAdmin"] = call_from("0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8", "_setPendingAdmin(address)", ["address"], [RAND])
out["c2_unitroller_setBorrowCaps"] = call_from("0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8", "_setMarketBorrowCaps(address[],uint256[])", ["address[]","uint256[]"], [["0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656"],[1]])
out["c2_unitroller_setPauseGuardian"] = call_from("0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8", "_setPauseGuardian(address)", ["address"], [RAND])
print("c3 revert:", out["c3_setTokenConfig_revert"])
print("c1 unitroller oracle:", out["c1_unitroller_setPriceOracle"])

with open(os.path.join(HERE, "childB-raw5.json"), "w") as f:
    json.dump(out, f, indent=2)
print("saved childB-raw5.json")
