#!/usr/bin/env python3
"""Child B batch 4b (light): Blockscout role logs with correct `topic` param; FTSO identity;
   poUpgrader roles; extra unitroller; same-block checks."""
import json, os, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]
BS = "https://flare-explorer.flare.network/api/v2"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}
RPC = RPCS[0]

def rpc(method, params):
    for r in RPCS:
        try:
            js = requests.post(r, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=45).json()
            if "result" in js: return js["result"]
        except Exception: pass
    return None

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
def eth_call(to, data, frm=None, blk="latest"):
    p = {"to": to, "data": data}
    if frm: p["from"] = frm
    return rpc("eth_call", [p, blk])

PO = "0x8f39EC8683Ff5af8f8Ad18563981f2C020E7EF32"
TL = "0x58b1b315319ce94fff3a665e2c4a7f61375aaba8"
UTU8127 = "0x81274d9250C8a36c62d3F45F18BD34D44D433b45"
UTU5B8A = "0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC"
CTUFAC3 = "0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7"
SAFE = "0x37C6C7c719DB93085678cE72981CDd96219C9B72"
C2_ORACLE = "0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c"
C1_ORACLE = "0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b"
C3_ORACLE = "0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D"
C3_UNITROLLER = "0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f"
FTSO_PROXY = "0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20"
FTSO_IMPL_SLOT = "0x15f816c9f9b0e80f684c88534c29cd618be32342"
FTSO_B18D = "0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32"
SFLR = "0x12e605bc104e93b45e1ad99f9e555f659051c2bb"

out = {}
latest = int(rpc("eth_blockNumber", []), 16)
out["block"] = latest

# 1. role logs via Blockscout `topic`
tG = "0x" + keccak(text="RoleGranted(bytes32,address,address)").hex()
tR = "0x" + keccak(text="RoleRevoked(bytes32,address,address)").hex()
roles = {"0x" + keccak(text=n).hex(): n for n in
         ["TIMELOCK_ADMIN_ROLE","PROPOSER_ROLE","EXECUTOR_ROLE","CANCELLER_ROLE","NO_DELAY_ROLE","DEFAULT_ADMIN_ROLE"]}
role_events = {}
for name, a in [("tl58b1", TL), ("utu8127", UTU8127), ("utu5b8a", UTU5B8A), ("ctufac3", CTUFAC3), ("po8f39", PO)]:
    evs = []
    for kind, t0 in [("GRANT", tG), ("REVOKE", tR)]:
        npp = None
        for _ in range(8):
            params = {"topic": t0}
            if npp: params.update(npp)
            js = bs(f"/addresses/{a}/logs", params)
            if not js or not js.get("items"): break
            for it in js["items"]:
                topics = it.get("topics") or []
                role = roles.get(topics[1], topics[1] if len(topics)>1 else "?")
                acct = "0x" + topics[2][-40:] if len(topics)>2 else "?"
                data = it.get("data") or "0x"
                sender = "0x" + data[-40:] if len(data) >= 66 else "?"
                evs.append({"kind": kind, "role": role, "account": acct, "sender": sender,
                            "block": it.get("block_number"), "tx": it.get("transaction_hash")})
            npp = js.get("next_page_params")
            if not npp: break
    role_events[name] = evs
    print(f"--- {name} ---")
    for e in evs: print("  ", e["block"], e["kind"], e["role"], "->", e["account"], "sender", e["sender"])

# 2. poUpgrader delay + roles
out["po8f39_getMinDelay"] = eth_call(PO, enc("getMinDelay()"))
out["po8f39_roles"] = {}
for rn in ["PROPOSER_ROLE","EXECUTOR_ROLE","CANCELLER_ROLE","TIMELOCK_ADMIN_ROLE","NO_DELAY_ROLE"]:
    rh = keccak(text=rn).hex()
    for who, an in [(SAFE,"safe"), (PO,"self"), (TL,"tl58b1"), ("0x0000000000000000000000000000000000000000","zero")]:
        res = eth_call(PO, enc("hasRole(bytes32,address)", ["bytes32","address"], [bytes.fromhex(rh), who]))
        out["po8f39_roles"][f"{rn}.{an}"] = None if not res else int(res,16)==1

# 3. extra unitroller (C3?)
out["c3_unitroller"] = {}
for sig in ["admin()","pendingAdmin()","oracle()","pauseGuardian()","comptrollerImplementation()"]:
    out["c3_unitroller"][sig] = eth_call(C3_UNITROLLER, enc(sig))

# 4. same-block FTSO vs oracle
FLR_FEED = bytes.fromhex("01464c522f55534400000000000000000000000000")
blk = hex(latest)
out["sameblock"] = {
    "block": latest,
    "ftso_b18d_FLR": eth_call(FTSO_B18D, enc("getFeedById(bytes21)", ["bytes21"], [FLR_FEED]), blk=blk),
    "ftso_proxy_FLR": eth_call(FTSO_PROXY, enc("getFeedById(bytes21)", ["bytes21"], [FLR_FEED]), blk=blk),
    "ftso_implslot_FLR": eth_call(FTSO_IMPL_SLOT, enc("getFeedById(bytes21)", ["bytes21"], [FLR_FEED]), blk=blk),
    "c2_getEtherPrice": eth_call(C2_ORACLE, enc("getEtherPrice()"), blk=blk),
    "c1_getEtherPrice": eth_call(C1_ORACLE, enc("getEtherPrice()"), blk=blk),
    "c2_getPrice_sFLR": eth_call(C2_ORACLE, enc("getPrice(address)", ["address"], [SFLR]), blk=blk),
    "sFLR_exchangeRate": eth_call(SFLR, enc("getExchangeRate()"), blk=blk),
}
# decode
def dec_uint(h): return int(h,16) if h else None
sb = out["sameblock"]
for k in ["ftso_b18d_FLR","ftso_proxy_FLR","ftso_implslot_FLR"]:
    h = sb[k]
    if h:
        raw = bytes.fromhex(h[2:])
        price = int.from_bytes(raw[0:32],"big"); decimals = int.from_bytes(raw[32:64],"big", signed=True); ts = int.from_bytes(raw[64:96],"big")
        sb[k+"_decoded"] = {"price": price, "decimals": decimals, "timestamp": ts}
for k in ["c2_getEtherPrice","c1_getEtherPrice","c2_getPrice_sFLR","sFLR_exchangeRate"]:
    sb[k+"_decoded"] = dec_uint(sb[k])

# 5. FTSO impl slot + b18d identity
for nm, a in [("implslot", FTSO_IMPL_SLOT), ("b18d", FTSO_B18D), ("proxy", FTSO_PROXY)]:
    info = bs(f"/addresses/{a}") or {}
    out[f"ftso_{nm}_info"] = {k: info.get(k) for k in ["name","is_contract","is_verified","proxy_type","creation_transaction_hash"]}
    code = rpc("eth_getCode", [a, "latest"]) or "0x"
    out[f"ftso_{nm}_codesize"] = max(0,(len(code)-2)//2)

# 6. C3 setTokenConfig sim with correct tuple
c3sim = rpc("eth_call", [{"to": C3_ORACLE, "from": "0x1111111111111111111111111111111111111111",
    "data": enc("setTokenConfig((address,bytes21,uint64,address))", ["(address,bytes21,uint64,address)"],
                [("0xfbda5f676cb37624f28265a144a48b0d6e87d3b6", bytes.fromhex("01"+"00"*20), 420, "0x"+"00"*20)])}, "latest"])
out["c3_setTokenConfig_sim"] = c3sim

with open(os.path.join(HERE, "childB-raw4.json"), "w") as f:
    json.dump({"block": latest, "role_events": role_events, **{k:v for k,v in out.items() if k!="block"}}, f, indent=2)
print("\npo8f39 minDelay:", out["po8f39_getMinDelay"], "roles:", json.dumps(out["po8f39_roles"]))
print("c3 unitroller:", json.dumps(out["c3_unitroller"]))
print("sameblock:", json.dumps(out["sameblock"], indent=1))
print("ftso implslot:", out["ftso_implslot_info"], out["ftso_implslot_codesize"])
print("ftso b18d:", out["ftso_b18d_info"], out["ftso_b18d_codesize"])
print("c3 sim:", str(out["c3_setTokenConfig_sim"])[:200])
print("saved childB-raw4.json")
