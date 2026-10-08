#!/usr/bin/env python3
"""Child B batch 4: role logs via eth_getLogs, poUpgrader roles/delay, extra Unitroller,
same-block FTSO-vs-oracle check, FTSO impl identity."""
import json, os, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]
BS = "https://flare-explorer.flare.network/api/v2"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}
RPC = RPCS[0]

def rpc(method, params, rpc_url=None):
    for r in ([rpc_url] if rpc_url else RPCS):
        try:
            js = requests.post(r, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=60).json()
            if "result" in js: return js["result"]
        except Exception: pass
    return None

def sel(sig): return keccak(text=sig)[:4].hex()
def enc(sig, atypes, avals):
    return "0x" + sel(sig) + abi_encode(atypes, avals).hex()

def eth_call(to, data, frm=None):
    p = {"to": to, "data": data}
    if frm: p["from"] = frm
    return rpc("eth_call", [p, "latest"])

out = {"generated_at_block": int(rpc("eth_blockNumber", []), 16)}

PO = "0x8f39EC8683Ff5af8f8Ad18563981f2C020E7EF32"
TL = "0x58b1b315319ce94fff3a665e2c4a7f61375aaba8"
UTU8127 = "0x81274d9250C8a36c62d3F45F18BD34D44D433b45"
UTU5B8A = "0x5b8A5e0009cf617f739aE254AE2a6d83471F10aC"
CTUFAC3 = "0xfaC3F74c3dDed68AAA5Cd6f37793fC792e74A4c7"
SAFE = "0x37C6C7c719DB93085678cE72981CDd96219C9B72"
C2_ORACLE = "0xC1d7029C970d9B683Da9d37b49d84D081dbeD54c"
C2_UNITROLLER = "0x8041680Fb73E1Fe5F851e76233DCDfA0f2D2D7c8"
C3_UNITROLLER = "0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f"
FTSO_PROXY = "0x7bde3df0624114edb3a67dfe6753e62f4e7c1d20"
FTSO_IMPL_SLOT = "0x15f816c9f9b0e80f684c88534c29cd618be32342"
FTSO_B18D = "0xb18d3a5e5a85c65ce47f977d7f486b79f99d3d32"

# creation blocks from receipts
creations = {
 "po8f39": "0xc2d0270b1843c78bc3032b21e53a723ef45a98ae061766eac8534e54ac0d618a",
 "tl58b1": "0x4d46fed8c6cbcd89106833f7352c6bd01dfed16b09f99f951389e9ace911a0a8",
 "utu8127": "0xaf592ea64b4d632d257b390eb52582e97ca8de8d5d2763a78f792e102af9c8d2",
 "utu5b8a": "0x85db280d58ff4ccc20159664a350479611d3f167410bfbbb9797182a7502d741",
 "ctufac3": "0xfaeeb8aa68821b4e28648f3915d143acd71259fb69c33ec2882e4ac91580727b",
 "unitroller_c3": None,
}
out["creation_blocks"] = {}
for k, tx in creations.items():
    if not tx: continue
    rc = rpc("eth_getTransactionReceipt", [tx])
    out["creation_blocks"][k] = int(rc["blockNumber"], 16) if rc else None
print("creation blocks:", out["creation_blocks"])

# search C3 unitroller creation via Blockscout
c3info = requests.get(f"{BS}/addresses/{C3_UNITROLLER}", headers=HDR, timeout=40).json()
out["c3_unitroller_creation_tx"] = c3info.get("creation_transaction_hash")
if c3info.get("creation_transaction_hash"):
    rc = rpc("eth_getTransactionReceipt", [c3info["creation_transaction_hash"]])
    out["creation_blocks"]["unitroller_c3"] = int(rc["blockNumber"], 16) if rc else None

# role logs via eth_getLogs, chunked
TOPIC_G = "0x" + keccak(text="RoleGranted(bytes32,address,address)").hex()
TOPIC_R = "0x" + keccak(text="RoleRevoked(bytes32,address,address)").hex()
targets = {"tl58b1": TL, "utu8127": UTU8127, "utu5b8a": UTU5B8A, "ctufac3": CTUFAC3, "po8f39": PO}
latest = int(rpc("eth_blockNumber", []), 16)
out["role_events"] = {}
for name, addr in targets.items():
    start = out["creation_blocks"].get({"tl58b1":"tl58b1","utu8127":"utu8127","utu5b8a":"utu5b8a","ctufac3":"ctufac3","po8f39":"po8f39"}[name]) or (latest - 8000000)
    logs = []
    frm = start
    while frm <= latest:
        to = min(frm + 400000, latest)
        js = rpc("eth_getLogs", [{"address": addr, "fromBlock": hex(frm), "toBlock": hex(to), "topics": [[TOPIC_G, TOPIC_R]]}])
        if js is None:
            # reduce chunk
            step = 100000
            sub = frm
            while sub <= to:
                subto = min(sub + step, to)
                js2 = rpc("eth_getLogs", [{"address": addr, "fromBlock": hex(sub), "toBlock": hex(subto), "topics": [[TOPIC_G, TOPIC_R]]}])
                if js2: logs.extend(js2)
                sub = subto + 1
            js = []
        else:
            logs.extend(js)
        frm = to + 1
    out["role_events"][name] = logs
    print(name, "events:", len(logs))

# poUpgrader delay + role checks + its own owner-ish
out["po8f39_getMinDelay"] = eth_call(PO, enc("getMinDelay()", [], []))
ROLES = {"PROPOSER": keccak(text="PROPOSER_ROLE").hex(), "EXECUTOR": keccak(text="EXECUTOR_ROLE").hex(),
         "CANCELLER": keccak(text="CANCELLER_ROLE").hex(), "TIMELOCK_ADMIN": keccak(text="TIMELOCK_ADMIN_ROLE").hex()}
out["po8f39_roles"] = {}
for rn, rh in ROLES.items():
    for who, an in [(SAFE,"safe"), (PO,"self"), (TL,"tl58b1")]:
        res = eth_call(PO, enc("hasRole(bytes32,address)", ["bytes32","address"], [bytes.fromhex(rh), who]))
        out["po8f39_roles"][f"{rn}.{an}"] = None if not res else int(res,16) == 1

# extra unitroller info
out["c3_unitroller"] = {}
for sig, atypes, avals in [("admin()",[],[]), ("oracle()",[],[]), ("pauseGuardian()",[],[]),
                           ("comptrollerImplementation()",[],[]), ("pendingAdmin()",[],[])]:
    out["c3_unitroller"][sig] = eth_call(C3_UNITROLLER, enc(sig, atypes, avals))

# same-block FTSO vs oracle
block = hex(out["generated_at_block"])
FLR_FEED = bytes.fromhex("01464c522f55534400000000000000000000000000")
def call_at(to, data, blk):
    return rpc("eth_call", [{"to": to, "data": data}, blk])
out["sameblock"] = {
    "block": out["generated_at_block"],
    "ftso_b18d_FLR": call_at(FTSO_B18D, enc("getFeedById(bytes21)", ["bytes21"], [FLR_FEED]), block),
    "ftso_proxy_FLR": call_at(FTSO_PROXY, enc("getFeedById(bytes21)", ["bytes21"], [FLR_FEED]), block),
    "ftso_implslot_FLR": call_at(FTSO_IMPL_SLOT, enc("getFeedById(bytes21)", ["bytes21"], [FLR_FEED]), block),
    "c2_getEtherPrice": call_at(C2_ORACLE, enc("getEtherPrice()", [], []), block),
    "c2_getPrice_sFLR": call_at(C2_ORACLE, enc("getPrice(address)", ["address"], ["0x12e605bc104e93b45e1ad99f9e555f659051c2bb"]), block),
    "c1_getEtherPrice": call_at("0x61f77Ef0064736Ffa68c31D960E55BAf67F79A4b", enc("getEtherPrice()", [], []), block),
}

# FTSO impl slot address identity on Blockscout
implinfo = requests.get(f"{BS}/addresses/{FTSO_IMPL_SLOT}", headers=HDR, timeout=40).json()
out["ftso_implslot_info"] = {k: implinfo.get(k) for k in ["name","is_contract","is_verified","proxy_type"]}
b18dinfo = requests.get(f"{BS}/addresses/{FTSO_B18D}", headers=HDR, timeout=40).json()
out["ftso_b18d_info"] = {k: b18dinfo.get(k) for k in ["name","is_contract","is_verified","proxy_type"]}
out["ftso_implslot_code"] = len(rpc("eth_getCode", [FTSO_IMPL_SLOT, "latest"]) or "0x")//2 - 1
out["ftso_b18d_code"] = len(rpc("eth_getCode", [FTSO_B18D, "latest"]) or "0x")//2 - 1

# redo C3 setTokenConfig sim with correct tuple
c3sim = rpc("eth_call", [{"to": "0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D",
     "from": "0x1111111111111111111111111111111111111111",
     "data": enc("setTokenConfig((address,bytes21,uint64,address))", ["(address,bytes21,uint64,address)"],
                 [("0xfbda5f676cb37624f28265a144a48b0d6e87d3b6", bytes.fromhex("01"+"00"*20), 420, "0x"+"00"*20)])}, "latest"])
out["c3_setTokenConfig_sim"] = c3sim

with open(os.path.join(HERE, "childB-raw4.json"), "w") as f:
    json.dump(out, f, indent=2)

# summarize role events
def fmt_role(topic):
    roles = {"0x" + keccak(text=n).hex(): n for n in ["TIMELOCK_ADMIN_ROLE","PROPOSER_ROLE","EXECUTOR_ROLE","CANCELLER_ROLE","NO_DELAY_ROLE"]}
    return roles.get(topic, topic)
for name, logs in out["role_events"].items():
    print(f"--- {name} role events ---")
    for lg in logs:
        topics = lg["topics"]; data = lg["data"]
        role = fmt_role(topics[1])
        acct = "0x" + topics[2][-40:]
        sender = "0x" + data[-40:] if data and len(data) >= 66 else "?"
        kind = "GRANT" if topics[0].lower() == TOPIC_G.lower() else "REVOKE"
        print(f"  blk {int(lg['blockNumber'],16)} {kind} {role} -> {acct} (sender {sender})")
print(json.dumps({k:v for k,v in out.items() if k not in ("role_events","sameblock")}, indent=1)[:2500])
