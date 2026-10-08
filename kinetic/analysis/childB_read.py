#!/usr/bin/env python3
"""Child B (verification): oracle privileges / FTSO dependency / approval allowlist.
Read-only JSON-RPC batch calls on Flare (chain 14). Writes childB-raw.json.
"""
import json, os, sys
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]

C1_ORACLE = "0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b"
C2_ORACLE = "0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c"
C3_ORACLE = "0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D"
C1_COMPTROLLER = "0x15F69897E6aEBE0463401345543C26d1Fd994abB"
C2_COMPTROLLER = "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8"
C1_ADMIN_CLAIM = "0x37C6C7c719DB93085678cE72981CDd96219C9B72"
C2_ADMIN_CLAIM = "0x81274d9250C8a36c62d3F45F18BD34D44D433b45"
CTOKEN_DELEGATOR_ADMIN = "0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7"
UPGRADER_2 = "0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC"
K_SFLR = "0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656"
FTSO_C1 = "0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20"
FTSO_C2C3 = "0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32"
REGISTRY = "0xaD67FE66660Fb8dFE9d6b1b4240d8650e30F6019"

# underlying / asset addresses on Flare
SFLR = "0x12e605bc104e93b45e1ad99f9e555f659051c2bb"
FXRP = "0xad552a648c74d49e10027ab8a618a3ad4901c5be"
USDC_E = "0xfbda5f676cb37624f28265a144a48b0d6e87d3b6"
USDT = "0x0b38e83b86d491735feaa0a791f65c2b99535396"
WETH = "0x1502fa4be69d526124d453619276faccab275d3d"
FLRETH = "0x26a1fab310bd080542dc864647d05985360b16a5"
USDT0 = "0xe7cd86e13ac4309349f30b3435a9d337750fc82d"
STXRP = "0x4c18ff3c89632c3dd62e796c0afa5c07c4c1b2b3"
ZERO = "0x0000000000000000000000000000000000000000"

def sel(sig):
    return keccak(text=sig)[:4].hex()

calls = []
def add(label, to, sig, atypes=None, avals=None):
    atypes = atypes or []; avals = avals or []
    data = "0x" + sel(sig) + (abi_encode(atypes, avals).hex() if atypes else "")
    calls.append({"label": label, "to": to, "data": data})

# 1. owners
for lbl, o in [("c1", C1_ORACLE), ("c2", C2_ORACLE), ("c3", C3_ORACLE)]:
    add(f"oracle.{lbl}.owner", o, "owner()")
    add(f"oracle.{lbl}.pendingOwner", o, "pendingOwner()")
    add(f"oracle.{lbl}.ftsoV2", o, "ftsoV2()")
    add(f"oracle.{lbl}.etherPrice", o, "getEtherPrice()")

# 2. comptroller admins
add("c1.admin", C1_COMPTROLLER, "admin()")
add("c1.pendingAdmin", C1_COMPTROLLER, "pendingAdmin()")
add("c2.admin", C2_COMPTROLLER, "admin()")
add("c2.pendingAdmin", C2_COMPTROLLER, "pendingAdmin()")
# 3. cToken delegator admin
add("ksflr.admin", K_SFLR, "admin()")
add("ksflr.implementation", K_SFLR, "implementation()")
add("ksflr.comptroller", K_SFLR, "comptroller()")
# 4. approval allowlist
add("ksflr.approvalAllowList", K_SFLR, "approvalAllowList()")
add("allowlist.allowed.randA", "0x59f6559051c67bc3b2fe4b9275770eff6616e0b7", "allowed(address)", ["address"], ["0x1111111111111111111111111111111111111111"])
add("allowlist.allowed.randB", "0x59f6559051c67bc3b2fe4b9275770eff6616e0b7", "allowed(address)", ["address"], ["0xdead00000000000000000000000000000000beef"])

# 5. tokenConfigs on C2 oracle (and C1 for cross-check)
assets = [("native0", ZERO), ("sFLR", SFLR), ("FXRP", FXRP), ("USDC.e", USDC_E), ("USDT", USDT),
          ("WETH", WETH), ("flrETH", FLRETH), ("USDT0", USDT0), ("stXRP", STXRP)]
for lbl, o in [("c2", C2_ORACLE), ("c1", C1_ORACLE), ("c3", C3_ORACLE)]:
    for an, a in assets:
        add(f"cfg.{lbl}.{an}", o, "tokenConfigs(address)", ["address"], [a])
    add(f"oracle.{lbl}.assetPrices.FXRP", o, "assetPrices(address)", ["address"], [FXRP])
    add(f"oracle.{lbl}.assetPrices.sFLR", o, "assetPrices(address)", ["address"], [SFLR])

# 6. registry name lookup FtsoV2
add("registry.FtsoV2", REGISTRY, "getContractAddressByName(string)", ["string"], ["FtsoV2"])
add("registry.FlareContractRegistry", REGISTRY, "getContractAddressByName(string)", ["string"], ["FlareContractRegistry"])

def rpc_batch(rpc, calls, block, chunk=20):
    out = {}
    for start in range(0, len(calls), chunk):
        part = calls[start:start+chunk]
        payload = [{"jsonrpc":"2.0","id": i, "method":"eth_call",
                    "params":[{"to": c["to"], "data": c["data"]}, hex(block)]}
                   for i, c in enumerate(part, start)]
        last = None
        for rpc_try in [rpc] + [x for x in RPCS if x != rpc]:
            try:
                r = requests.post(rpc_try, json=payload, timeout=60)
                r.raise_for_status()
                js = r.json()
                for item in js:
                    out[item["id"]] = item.get("result", item.get("error"))
                last = None
                break
            except Exception as e:
                last = e
        if last: raise last
    return out

def main():
    rpc = None; block = None
    for r in RPCS:
        try:
            rr = requests.post(r, json={"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}, timeout=20)
            block = int(rr.json()["result"], 16); rpc = r; break
        except Exception as e:
            print("rpc fail", r, e)
    if not rpc: sys.exit(1)
    print("rpc:", rpc, "block:", block)
    res = rpc_batch(rpc, calls, block)

    # decode everything generically + collect raw
    decoded = {}
    for i, c in enumerate(calls):
        raw = res.get(i)
        decoded[c["label"]] = raw
    # code sizes + code hashes
    extras = {}
    addrs = {
        "oracle.c1.owner": None, "oracle.c2.owner": None, "oracle.c3.owner": None,
    }
    # get code for key addresses
    code_targets = [C1_ORACLE, C2_ORACLE, C3_ORACLE, C1_COMPTROLLER, C2_COMPTROLLER,
                    C1_ADMIN_CLAIM, C2_ADMIN_CLAIM, CTOKEN_DELEGATOR_ADMIN, UPGRADER_2,
                    FTSO_C1, FTSO_C2C3, K_SFLR]
    payload = [{"jsonrpc":"2.0","id":i,"method":"eth_getCode","params":[a, hex(block)]} for i,a in enumerate(code_targets)]
    cr = requests.post(rpc, json=payload, timeout=60).json()
    codes = {}
    for i, a in enumerate(code_targets):
        val = next(x["result"] for x in cr if x["id"] == i)
        codes[a] = {"size": (len(val)-2)//2 if val and val != "0x" else 0,
                    "keccak": keccak(hexstr=val).hex() if val and val!="0x" else None}

    out = {"rpc": rpc, "block": block, "decoded": decoded, "codes": codes}
    # decode helper for a few
    def dec(label, rtypes):
        raw = decoded.get(label)
        if not isinstance(raw, str): return f"RPC_ERR:{raw}"
        if not raw or raw in ("0x","0x0"): return None
        try:
            vals = abi_decode(rtypes, bytes.fromhex(raw[2:]))
            return vals[0] if len(vals)==1 else [str(v) for v in vals]
        except Exception as e:
            return f"ERR:{e}:{raw[:100]}"
    pretty = {}
    for lbl in ["oracle.c1.owner","oracle.c2.owner","oracle.c3.owner","oracle.c1.pendingOwner","oracle.c2.pendingOwner","oracle.c3.pendingOwner"]:
        pretty[lbl] = dec(lbl, ["address"])
    for lbl in ["oracle.c1.ftsoV2","oracle.c2.ftsoV2","oracle.c3.ftsoV2","c1.admin","c1.pendingAdmin","c2.admin","c2.pendingAdmin","ksflr.admin","ksflr.implementation","ksflr.comptroller","ksflr.approvalAllowList","registry.FtsoV2","registry.FlareContractRegistry"]:
        pretty[lbl] = dec(lbl, ["address"])
    for lbl in ["allowlist.allowed.randA","allowlist.allowed.randB"]:
        pretty[lbl] = dec(lbl, ["bool"])
    for lbl in ["oracle.c1.etherPrice","oracle.c2.etherPrice","oracle.c3.etherPrice"]:
        pretty[lbl] = dec(lbl, ["uint256"])
    for lbl in decoded:
        if lbl.startswith("cfg."):
            pretty[lbl] = dec(lbl, ["address","bytes21","uint64","address"])
    out["pretty"] = pretty
    with open(os.path.join(HERE, "childB-raw.json"), "w") as f:
        json.dump(out, f, indent=2)
    print(json.dumps(pretty, indent=1))

if __name__ == "__main__":
    main()
