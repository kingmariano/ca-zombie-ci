#!/usr/bin/env python3
"""Test every candidate selector against the proxy: registered vs no-impl (captures revert data)."""
import json, sys, time, urllib.request

RPC = "https://ethereum-rpc.publicnode.com"
PROXY = "0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756"
cands = {
 "proxy_native_0x6e": "6e", "proxy_native_0xcf": "cf", "proxy_native_0xf8": "f8",
 "proxy_0x972fdd26": "972fdd26", "proxy_0xfa461e33": "fa461e33", "proxy_0x3b6d0340": "3b6d0340",
 "old_0x01e480ab": "01e480ab", "old_0x06c1f431": "06c1f431", "old_0x240028e8": "240028e8",
 "old_0x2ba8d939": "2ba8d939", "old_0x3fabe5a3": "3fabe5a3", "old_0x4112e1c2": "4112e1c2",
 "old_0x5d4d8fe7": "5d4d8fe7", "old_0x5df4fd38": "5df4fd38", "old_0x637fec51": "637fec51",
 "old_0x7179a12c": "7179a12c", "old_0x8da5cb5b": "8da5cb5b", "old_0x9227b794": "9227b794",
 "old_0x94be834d": "94be834d", "old_0xb9e7bce6": "b9e7bce6", "old_0xcbfd8657": "cbfd8657",
 "old_0xdcbbc8d4": "dcbbc8d4", "old_0xea7faa61": "ea7faa61",
 "new_0x031b905c": "031b905c", "new_0x0ee8be1b": "0ee8be1b", "new_0x261fe679": "261fe679",
 "new_0x6ae4b4f7": "6ae4b4f7", "new_0x78890e9c": "78890e9c", "new_0xf2fde38b": "f2fde38b",
 "new_0xfb969b0a": "fb969b0a",
 "admin_rollback_0x9db64a40": "9db64a40",
}

def raw_batch(items, retries=4):
    payload = [{"jsonrpc":"2.0","id":i+1,"method":"eth_call",
                "params":[{"to":PROXY,"data":"0x"+s},"latest"]} for i,(_,s) in enumerate(items)]
    data = json.dumps(payload).encode()
    for a in range(retries):
        try:
            req = urllib.request.Request(RPC, data=data, headers={"Content-Type":"application/json","User-Agent":"c25"})
            with urllib.request.urlopen(req, timeout=60) as r:
                out = json.loads(r.read().decode())
            byid = {o["id"]: o for o in out}
            return [byid.get(i+1) for i in range(len(items))]
        except Exception:
            if a==retries-1: raise
            time.sleep(2*(a+1))

res = raw_batch(list(cands.items()))
out = {}
for (name, sel), r in zip(cands.items(), res):
    if r is None: cls, val = "missing", None
    elif "error" in r:
        msg = json.dumps(r["error"])
        cls = "UNREGISTERED" if "734e6e1c" in msg else "REGISTERED"
        val = r["error"].get("data", msg)[:100]
    else:
        cls, val = "REGISTERED", str(r.get("result"))[:100]
    out[name] = {"selector": sel, "class": cls, "result": val}
print(json.dumps(out, indent=2))
with open("/home/heisenberg/CA/c-25/analysis/selector_registry.json", "w") as f:
    json.dump(out, f, indent=2)
