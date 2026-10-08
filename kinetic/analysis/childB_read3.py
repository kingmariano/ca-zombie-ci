#!/usr/bin/env python3
"""Child B batch 3: identify priceOracleUpgrader 0x8f39ec, enumerate role holders via logs,
   check Safe owners are EOAs, AllowList owner, revert simulations for unprivileged callers."""
import json, os, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]
BS = "https://flare-explorer.flare.network/api/v2"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

PO_UPGRADER = "0x8f39ec8683ff5af8f8ad18563981f2c020e7ef32"
TL_C2_ORACLE_OWNER = "0x58b1b315319ce94fff3a665e2c4a7f61375aaba8"
UTU_8127 = "0x81274d9250C8a36c62d3F45F18BD34D44D433b45"
UTU_5b8a = "0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC"
CTU_fac3 = "0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7"
SAFE = "0x37C6C7c719DB93085678cE72981CDd96219C9B72"
ALLOWLIST = "0x59f6559051c67bc3b2fe4b9275770eff6616e0b7"
C2_ORACLE = "0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c"
C1_ORACLE = "0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b"
C3_ORACLE = "0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D"
K_SFLR = "0x291487beC339c2fE5D83DD45F0a15EFC9Ac45656"
USDC_E = "0xfbda5f676cb37624f28265a144a48b0d6e87d3b6"

def sel(sig): return keccak(text=sig)[:4].hex()

def bs_get(path, params=None):
    for _ in range(3):
        try:
            r = requests.get(BS + path, headers=HDR, params=params, timeout=40)
            if r.status_code == 200: return r.json()
            time.sleep(1.2)
        except Exception: time.sleep(1.2)
    return None

out = {}

# 1. Blockscout info for priceOracleUpgrader + search Unitroller contracts
out["po_upgrader_info"] = {k: v for k, v in (bs_get(f"/addresses/{PO_UPGRADER}") or {}).items()
                           if k in ["hash","is_contract","name","is_verified","proxy_type","implementation","creator_address_hash","creation_transaction_hash"]}
src = bs_get(f"/smart-contracts/{PO_UPGRADER}")
if src:
    with open(os.path.join(HERE, "childB-src", "priceOracleUpgrader_8f39.sol"), "w") as f:
        f.write(src.get("source_code") or "")
        for c in (src.get("additional_sources") or []):
            f.write(f"\n\n// ===== additional: {c.get('file_path')} =====\n")
            f.write(c.get("source_code") or "")
    out["po_upgrader_src_name"] = src.get("name")
    print("po upgrader:", src.get("name"), out["po_upgrader_info"])

# 2. RoleGranted/RoleRevoked logs on the four timelocks + po_upgrader (Blockscout)
topic_granted = "0x" + keccak(text="RoleGranted(bytes32,address,address)").hex()
topic_revoked = "0x" + keccak(text="RoleRevoked(bytes32,address,address)").hex()
out["role_logs"] = {}
for name, a in [("tlOwner58b1", TL_C2_ORACLE_OWNER), ("utu8127", UTU_8127), ("utu5b8a", UTU_5b8a),
                ("ctuFac3", CTU_fac3), ("poUpgrader8f39", PO_UPGRADER)]:
    logs = []
    for t0 in (topic_granted, topic_revoked):
        js = bs_get(f"/addresses/{a}/logs", {"topic0": t0})
        if js and js.get("items"):
            for it in js["items"]:
                logs.append({"topic0": it.get("topic") or t0, "topics": it.get("topics"),
                             "block": it.get("block_number"), "tx": it.get("transaction_hash"),
                             "data": it.get("data")})
            # pagination: follow next_page_params
            npp = js.get("next_page_params")
            guard = 0
            while npp and guard < 10:
                js = bs_get(f"/addresses/{a}/logs", {**{"topic0": t0}, **npp})
                if not js or not js.get("items"): break
                for it in js["items"]:
                    logs.append({"topic0": it.get("topic") or t0, "topics": it.get("topics"),
                                 "block": it.get("block_number"), "tx": it.get("transaction_hash"),
                                 "data": it.get("data")})
                npp = js.get("next_page_params"); guard += 1
    out["role_logs"][name] = logs
    print(name, "role logs:", len(logs))

# 3. Safe owners code check (EOA?) + AllowList details + search unitroller instances
owners = ["0x618bbc6bfd52a9f469c4c6e5446ac032138f173a","0x77530a7455e76ebb1d00b336cd0abe0a70f6e900",
          "0x164a697d88d93d8c46061fd54f2dcfadeddafa33","0x16cc7ad2ba05a7892526ce25534d6f72163b4f47",
          "0xd8a1ff9875b504954de8a595e0c5d388e43778a1","0x99c83fadf782350fde9505fffc5dd3face22105d",
          "0xda8f3c44a1614b2012a7e948504d56392aa3f0c5"]
out["safe_owner_code"] = {}
payload = [{"jsonrpc":"2.0","id":i,"method":"eth_getCode","params":[a,"latest"]} for i,a in enumerate(owners)]
r = requests.post(RPCS[0], json=payload, timeout=60).json()
for i, a in enumerate(owners):
    code = next(x["result"] for x in r if x["id"]==i)
    out["safe_owner_code"][a] = {"size": (len(code)-2)//2}
print("safe owner sizes:", {k: v["size"] for k,v in out["safe_owner_code"].items()})

# 4. search Unitroller contracts
search = bs_get("/search", {"q": "Unitroller"})
out["search_unitroller"] = search
print("search Unitroller:", json.dumps(search)[:400] if search else None)

# 5. AllowList owner
def call(to, sig, atypes=None, avals=None, frm=None):
    data = "0x" + sel(sig) + (abi_encode(atypes or [], avals or []).hex() if atypes else "")
    p = {"to": to, "data": data}
    if frm: p["from"] = frm
    rr = requests.post(RPCS[0], json={"jsonrpc":"2.0","id":1,"method":"eth_call","params":[p,"latest"]}, timeout=30).json()
    return rr.get("result", rr.get("error"))
out["allowlist_owner_raw"] = call(ALLOWLIST, "owner()")
out["allowlist_pendingOwner_raw"] = call(ALLOWLIST, "pendingOwner()")

# 6. Revert simulation: unprivileged external calls
RAND = "0x1111111111111111111111111111111111111111"
sims = [
    ("c2.setPrice", C2_ORACLE, "setPrice(address,uint256)", ["address","uint256"], [USDC_E, 1]),
    ("c2.setEtherPrice", C2_ORACLE, "setEtherPrice(uint256)", ["uint256"], [1]),
    ("c2.setFTSOV2", C2_ORACLE, "setFTSOV2(address)", ["address"], [RAND]),
    ("c2.setTokenConfig", C2_ORACLE, "setTokenConfig((address,bytes21,uint64,address))",
     ["(address,bytes21,uint64,address)"], [(USDC_E, bytes.fromhex("01"+"00"*20), 420, "0x"+"00"*20)]),
    ("c1.setPrice", C1_ORACLE, "setPrice(address,uint256)", ["address","uint256"], [USDC_E, 1]),
    ("c3.setTokenConfig", C3_ORACLE, "setTokenConfig((string,bytes21,uint64))",
     ["(string,bytes21,uint64)"], [("USDC", bytes.fromhex("01"+"00"*20), 420)]),
    ("c2.oracle.setUnderlyingPrice", C2_ORACLE, "setUnderlyingPrice(address,uint256)", ["address","uint256"], [K_SFLR, 1]),
    ("ksflr.approve.rand", K_SFLR, "approve(address,uint256)", ["address","uint256"], [RAND, 1]),
    ("ksflr.approve.zero", K_SFLR, "approve(address,uint256)", ["address","uint256"], [RAND, 0]),
    ("ksflr.setApprovalAllowList", K_SFLR, "_setApprovalAllowList(address)", ["address"], [RAND]),
    ("allowlist.allow.rand", ALLOWLIST, "allow(address)", ["address"], [RAND]),
    ("c2.unitroller._setPriceOracle", "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8", "_setPriceOracle(address)", ["address"], [RAND]),
    ("c2.unitroller._setCollateralFactor", "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8", "_setCollateralFactor(address,uint256)", ["address","uint256"], [K_SFLR, 0]),
    ("utu8127._setCollateralFactor", UTU_8127, "_setCollateralFactor(address,uint256)", ["address","uint256"], [K_SFLR, 0]),
    ("utu8127._setPriceOracle", UTU_8127, "_setPriceOracle(address)", ["address"], [RAND]),
]
out["sims"] = {}
for label, to, sig, atypes, avals in sims:
    res = call(to, sig, atypes, avals, frm=RAND)
    # try to decode revert reason if error
    out["sims"][label] = res
    print(label, "->", str(res)[:160])

with open(os.path.join(HERE, "childB-raw3.json"), "w") as f:
    json.dump(out, f, indent=2)
print("saved childB-raw3.json")
