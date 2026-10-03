#!/usr/bin/env python3
"""Query proxy.getFunctionImplementation(bytes4) for all known selectors (left-aligned bytes4)."""
import json, time, urllib.request

RPC = "https://ethereum-rpc.publicnode.com"
PROXY = "0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756"
sels = ["6e000000","cf000000","f8000000","972fdd26","fa461e33","3b6d0340",
 "01e480ab","06c1f431","240028e8","2ba8d939","3fabe5a3","4112e1c2","5d4d8fe7","5df4fd38",
 "637fec51","7179a12c","8da5cb5b","9227b794","94be834d","b9e7bce6","cbfd8657","dcbbc8d4","ea7faa61",
 "031b905c","0ee8be1b","261fe679","6ae4b4f7","78890e9c","f2fde38b","fb969b0a",
 "9db64a40","01ffc9a7","7a0ed627","adfca15e","52ef6b2c","cdffacc6"]

def enc(sel):
    return "0x972fdd26" + sel + "00" * 28

payload = [{"jsonrpc":"2.0","id":i+1,"method":"eth_call",
            "params":[{"to":PROXY,"data":enc(s)},"latest"]} for i,s in enumerate(sels)]
data = json.dumps(payload).encode()
for a in range(5):
    try:
        req = urllib.request.Request(RPC, data=data, headers={"Content-Type":"application/json","User-Agent":"c25"})
        with urllib.request.urlopen(req, timeout=60) as r:
            out = json.loads(r.read().decode())
        break
    except Exception:
        if a==4: raise
        time.sleep(2*(a+1))
byid = {o["id"]: o for o in out}
res = {}
for i, s in enumerate(sels):
    o = byid.get(i+1, {})
    if "result" in o and o["result"] and o["result"] != "0x":
        raw = o["result"]
        impl = "0x" + raw[-40:] if len(raw) >= 42 else raw
        res[s] = impl
        print(f"0x{s} -> {impl}")
    else:
        err = json.dumps(o.get("error", {}))[:120]
        res[s] = None
        print(f"0x{s} -> NONE/revert {err}")
with open("/home/heisenberg/CA/c-25/analysis/function_impl_registry.json", "w") as f:
    json.dump(res, f, indent=2)
