#!/usr/bin/env python3
"""Child B batch 6: allowlist entry identity, PauseGuardian source/owner, C3 tokenConfigs,
   extra unitroller markets identity, FTSO creation blocks."""
import json, os, time
import requests
from eth_utils import keccak
from eth_abi import encode as abi_encode, decode as abi_decode

HERE = os.path.dirname(os.path.abspath(__file__))
RPCS = ["https://14.rpc.thirdweb.com", "https://flare.public-rpc.com", "https://rpc.ankr.com/flare"]
BS = "https://flare-explorer.flare.network/api/v2"
HDR = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) research"}

def rpc(method, params):
    for r in RPCS:
        try:
            js = requests.post(r, json={"jsonrpc":"2.0","id":1,"method":method,"params":params}, timeout=45).json()
            if "result" in js or "error" in js: return js
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
def call(to, data):
    return rpc("eth_call", [{"to": to, "data": data}, "latest"]).get("result")

out = {}
# identities
for name, a in [("allowlist_entry","0x72b8cb893bd9350fa175ef0e62a667d07c7ffc86"),
                ("extra_unitroller","0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f"),
                ("extra_oracle","0x4d309754eb1ae09e94bfc2b5cb3178a317e76273"),
                ("extra_impl","0xa43b4b6934cbfe1f2afdbfdad668410b99c4410c"),
                ("pause_c1","0x5C37a9c61d7c9349b399EDc78f00AA90710b2B75"),
                ("pause_c2","0x452b97fdcb1bcf333112bf7920a81161de29f41d")]:
    info = bs(f"/addresses/{a}") or {}
    out[name] = {"name": info.get("name"), "is_verified": info.get("is_verified"),
                 "creator": info.get("creator_address_hash"), "proxy_type": info.get("proxy_type"),
                 "creation_tx": info.get("creation_transaction_hash")}
    print(name, out[name])

# pause guardian owners
for name, a in [("pause_c1","0x5C37a9c61d7c9349b399EDc78f00AA90710b2B75"),
                ("pause_c2","0x452b97fdcb1bcf333112bf7920a81161de29f41d")]:
    out[name+"_owner"] = call(a, enc("owner()"))
    out[name+"_pausedFlags"] = {
        "transferPaused": call(a, enc("transferPaused()")),
        "seizePaused": call(a, enc("seizePaused()")),
    }
    print(name, "owner", out[name+"_owner"], out[name+"_pausedFlags"])

# PauseGuardian source
src = bs("/smart-contracts/0x5C37a9c61d7c9349b399EDc78f00AA90710b2B75")
if src:
    with open(os.path.join(HERE,"childB-src","PauseGuardian_5C37.sol"),"w") as f:
        f.write(src.get("source_code") or "")

# C3 oracle tokenConfigs by symbol
C3 = "0x30eDf82B2B75BbBf8e0b04b0F59086d321af964D"
out["c3_configs"] = {}
for sym in ["FLR","sFLR","XRP","USDC","USDT","ETH","WETH","stXRP","flrETH"]:
    r = call(C3, enc("tokenConfigs(string)", ["string"], [sym]))
    if r and r != "0x":
        try:
            vals = abi_decode(["address","bytes21","uint64","address"], bytes.fromhex(r[2:]))
            out["c3_configs"][sym] = [vals[0], "0x"+vals[1].hex(), vals[2], vals[3]]
        except Exception as e:
            out["c3_configs"][sym] = f"decode err {e}"
    else:
        out["c3_configs"][sym] = None
print("c3 configs:", json.dumps(out["c3_configs"], indent=1)[:800])

# extra unitroller markets + oracle owner
mk = call("0xEBf6ed25aB1F79B5C10C7145C5167367bE31651f", enc("getAllMarkets()"))
out["extra_markets_raw"] = mk
if mk:
    try:
        mkts = abi_decode(["address[]"], bytes.fromhex(mk[2:]))[0]
        syms = []
        for m in mkts[:12]:
            s = call(m, enc("symbol()"))
            if s:
                try: syms.append(abi_decode(["string"], bytes.fromhex(s[2:]))[0])
                except Exception: syms.append("?")
            else: syms.append("??")
        out["extra_markets_symbols"] = syms
    except Exception as e:
        out["extra_markets_symbols"] = f"err {e}"
out["extra_oracle_owner"] = call("0x4d309754eb1ae09e94bfc2b5cb3178a317e76273", enc("owner()"))
print("extra markets:", out.get("extra_markets_symbols"), "oracle owner:", out["extra_oracle_owner"])

# FTSO creation blocks
for name, tx in [("ftso_proxy_7bde","0x7529c83d7e0c4849743eb849e9b937c73d68b3441a89efbdbd182c79eaf40a14"),
                 ("ftso_b18d","0x175a43a482ee813892985e5932ca46c825ce3369883c68189076f20926ee6732"),
                 ("ftso_implslot_15f8","0x341a87ebb4ffa14fa11a46a7dc0293ef4fdef9e7ee63f65b0afa5d298b5ac0f6")]:
    rc = rpc("eth_getTransactionReceipt", [tx]).get("result")
    out[name+"_block"] = int(rc["blockNumber"],16) if rc else None
print("ftso creation blocks:", {k:v for k,v in out.items() if k.endswith("_block")})

with open(os.path.join(HERE,"childB-raw6.json"),"w") as f:
    json.dump(out, f, indent=2)
print("saved childB-raw6.json")
