#!/usr/bin/env python3
"""Child B batch 2: FTSO feed values, timelock roles/delays, Safe owners."""
import json, os
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]

FTso_PROXY = "0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20"
FTso_IMPL = "0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32"
TL_C2_ORACLE_OWNER = "0x58b1b315319ce94fff3a665e2c4a7f61375aaba8"   # TimelockController owns C2 oracle
UTU_8127 = "0x81274d9250C8a36c62d3F45F18BD34D44D433b45"             # C2 unitroller admin
UTU_5b8a = "0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC"
CTU_fac3 = "0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7"             # cToken delegator admin
SAFE_37c6 = "0x37C6C7c719DB93085678cE72981CDd96219C9B72"           # C1 oracle owner + C1 unitroller admin

FLR_FEED = bytes.fromhex("01464c522f55534400000000000000000000000000")  # bytes21 FLR/USD
XRP_FEED = bytes.fromhex("015852502f55534400000000000000000000000000")  # bytes21 XRP/USD

def sel(sig): return keccak(text=sig)[:4].hex()

def role(name): return keccak(text=name)

calls = []
def add(label, to, sig, atypes=None, avals=None):
    atypes = atypes or []; avals = avals or []
    data = "0x" + sel(sig) + (abi_encode(atypes, avals).hex() if atypes else "")
    calls.append({"label": label, "to": to, "data": data})

# FTSO
add("ftso.proxy.getFeedById.FLR", FTso_PROXY, "getFeedById(bytes21)", ["bytes21"], [FLR_FEED])
add("ftso.impl.getFeedById.FLR", FTso_IMPL, "getFeedById(bytes21)", ["bytes21"], [FLR_FEED])
add("ftso.proxy.getFeedById.XRP", FTso_PROXY, "getFeedById(bytes21)", ["bytes21"], [XRP_FEED])
add("ftso.impl.getFeedById.XRP", FTso_IMPL, "getFeedById(bytes21)", ["bytes21"], [XRP_FEED])
add("ftso.proxy.version", FTso_PROXY, "version()")
add("ftso.impl.FTSO_PROTOCOL_ID", FTso_IMPL, "FTSO_PROTOCOL_ID()")
add("ftso.proxy.FTSO_PROTOCOL_ID", FTso_PROXY, "FTSO_PROTOCOL_ID()")

for name, a in [("tlOwner58b1", TL_C2_ORACLE_OWNER), ("utu8127", UTU_8127), ("utu5b8a", UTU_5b8a), ("ctuFac3", CTU_fac3)]:
    add(f"{name}.getMinDelay", a, "getMinDelay()")
for name, a in [("utu8127", UTU_8127), ("utu5b8a", UTU_5b8a)]:
    add(f"{name}.priceOracleUpgrader", a, "priceOracleUpgrader()")
add("utu8127.unitroller", UTU_8127, "unitroller()")
add("utu5b8a.unitroller", UTU_5b8a, "unitroller()")
add("ctuFac3.CERc20Delegator", CTU_fac3, "CERc20Delegator()")

# roles — candidates
cands = [SAFE_37c6, TL_C2_ORACLE_OWNER, UTU_8127, UTU_5b8a, CTU_fac3,
         "0x0000000000000000000000000000000000000000",
         "0x5C37a9c61d7c9349b399EDc78f00AA90710b2B75",  # C1 pauseGuardian
         "0x452b97fdcb1bcf333112bf7920a81161de29f41d"]  # C2 pauseGuardian
ROLES = {
  "PROPOSER": role("PROPOSER_ROLE"), "EXECUTOR": role("EXECUTOR_ROLE"),
  "CANCELLER": role("CANCELLER_ROLE"), "TIMELOCK_ADMIN": role("TIMELOCK_ADMIN_ROLE"),
  "NO_DELAY": role("NO_DELAY_ROLE"),
}
for name, a in [("tlOwner58b1", TL_C2_ORACLE_OWNER), ("utu8127", UTU_8127), ("utu5b8a", UTU_5b8a), ("ctuFac3", CTU_fac3)]:
    for rn, rh in ROLES.items():
        for i, c in enumerate(cands):
            add(f"role.{name}.{rn}.{i}", a, "hasRole(bytes32,address)", ["bytes32","address"], [rh, c])

# Safe
add("safe.version", SAFE_37c6, "VERSION()")
add("safe.getThreshold", SAFE_37c6, "getThreshold()")
add("safe.getOwners", SAFE_37c6, "getOwners()")
add("safe.nonce", SAFE_37c6, "nonce()")

def rpc_batch(rpc, calls, block, chunk=25):
    out = {}
    for start in range(0, len(calls), chunk):
        part = calls[start:start+chunk]
        payload = [{"jsonrpc":"2.0","id": i, "method":"eth_call",
                    "params":[{"to": c["to"], "data": c["data"]}, hex(block)]}
                   for i, c in enumerate(part, start)]
        last = None
        for rpc_try in [rpc] + [x for x in RPCS if x != rpc]:
            try:
                r = requests.post(rpc_try, json=payload, timeout=60); r.raise_for_status()
                for item in r.json(): out[item["id"]] = item.get("result", item)
                last = None; break
            except Exception as e:
                last = e
        if last: raise last
    return out

rpc = RPCS[0]
block = int(requests.post(rpc, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, timeout=20).json()["result"],16)
res = rpc_batch(rpc, calls, block)
decoded = {c["label"]: res.get(i) for i, c in enumerate(calls)}

def dec(label, rtypes):
    raw = decoded.get(label)
    if not isinstance(raw, str): return f"RPCERR:{raw}"
    if raw in ("0x","0x0"): return None
    try:
        vals = abi_decode(rtypes, bytes.fromhex(raw[2:]))
        return vals[0] if len(vals)==1 else [str(v) for v in vals]
    except Exception as e: return f"ERR:{e}"

# EIP-1967 impl slot of proxy (storage)
slot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
st = requests.post(rpc, json={"jsonrpc":"2.0","id":1,"method":"eth_getStorageAt","params":[FTso_PROXY, slot, hex(block)]}, timeout=20).json()["result"]
impl_in_proxy = "0x" + st[-40:]

pretty = {
    "block": block,
    "ftso_proxy_impl_slot": impl_in_proxy,
}
for lbl in ["ftso.proxy.getFeedById.FLR","ftso.impl.getFeedById.FLR","ftso.proxy.getFeedById.XRP","ftso.impl.getFeedById.XRP"]:
    pretty[lbl] = dec(lbl, ["uint256","int8","uint64"])
for lbl in ["ftso.proxy.version","ftso.impl.FTSO_PROTOCOL_ID","ftso.proxy.FTSO_PROTOCOL_ID"]:
    pretty[lbl] = dec(lbl, ["uint64"])
for name in ["tlOwner58b1","utu8127","utu5b8a","ctuFac3"]:
    pretty[f"{name}.getMinDelay"] = dec(f"{name}.getMinDelay", ["uint256"])
for lbl in ["utu8127.priceOracleUpgrader","utu5b8a.priceOracleUpgrader","utu8127.unitroller","utu5b8a.unitroller","ctuFac3.CERc20Delegator"]:
    pretty[lbl] = dec(lbl, ["address"])
pretty["safe.version"] = dec("safe.version", ["string"])
pretty["safe.getThreshold"] = dec("safe.getThreshold", ["uint256"])
pretty["safe.getOwners"] = dec("safe.getOwners", ["address[]"])
pretty["safe.nonce"] = dec("safe.nonce", ["uint256"])

roles_true = {}
for name in ["tlOwner58b1","utu8127","utu5b8a","ctuFac3"]:
    for rn in ROLES:
        for i, c in enumerate(cands):
            v = dec(f"role.{name}.{rn}.{i}", ["bool"])
            if v is True:
                roles_true.setdefault(name, {}).setdefault(rn, []).append(c)
pretty["roles_true"] = roles_true

with open(os.path.join(HERE, "childB-raw2.json"), "w") as f:
    json.dump({"block": block, "pretty": pretty, "decoded": decoded}, f, indent=2)
print(json.dumps(pretty, indent=1))
