#!/usr/bin/env python3
"""Check scFUSD debtors: current debt, asset lists, liquidity (correct first-word decode)."""
import json, time, urllib.request

RPC = "https://fantom.drpc.org"
CTRL = "0x260e596dabe3afc463e75b6cc05d8c46acacfb09"
FUSD = "0x4e6854ea84884330207fb557d1555961d85fc17e"

def pad(a): return a[2:].lower().rjust(64, "0")
RPC_POOL = ["https://rpcapi.fantom.network", "https://fantom.api.onfinality.io/public", "https://fantom.drpc.org"]
_rpc_i = [0]

def post(payload):
    last = None
    for attempt in range(9):
        url = RPC_POOL[_rpc_i[0] % len(RPC_POOL)]
        req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                     headers={"Content-Type": "application/json", "User-Agent": "research/1.0"})
        try:
            return json.loads(urllib.request.urlopen(req, timeout=40).read())
        except Exception as e:
            last = e
            _rpc_i[0] += 1
            time.sleep(1.0 + attempt * 0.5)
    raise last

def call(to, sel, arg=None):
    data = sel + (pad(arg) if arg else "")
    r = post({"jsonrpc": "2.0", "id": 1, "method": "eth_call", "params": [{"to": to, "data": data}, "latest"]})
    return r.get("result", {"error": r.get("error")})

def fw(r):
    if isinstance(r, str) and len(r) >= 66: return int(r[2:66], 16)
    return None

def decode_arr(r):
    if not isinstance(r, str) or len(r) < 130: return r
    b = r[2:]; off = int(b[:64], 16); ln = int(b[off*2:off*2+64], 16)
    return ["0x" + b[(off+32+i*32)*2+24:(off+32+i*32+32)*2] for i in range(ln)]

debtors = json.load(open("/home/heisenberg/CA/scream/analysis/debtors_scFUSD.json"))
print("checking", len(debtors), "scFUSD debtors")
for a in debtors:
    debt = fw(call(FUSD, "0x17bfdfbc", a))  # borrowBalanceCurrent
    stored = fw(call(FUSD, "0x95dd9193", a))
    assets = decode_arr(call(CTRL, "0xabfceffc", a))
    liq = call(CTRL, "0x5ec88c79", a)
    lq = None
    if isinstance(liq, str) and len(liq) >= 194:
        b = liq[2:]
        lq = {"err": int(b[:64], 16), "liquidity": int(b[64:128], 16), "shortfall": int(b[128:192], 16)}
    else:
        lq = {"error": liq}
    print(f"{a} debt={debt/1e18 if debt else debt} stored={stored/1e18 if stored else stored}")
    print(f"   assets={assets}")
    print(f"   liq={lq}")
