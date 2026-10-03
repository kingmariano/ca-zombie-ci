#!/usr/bin/env python3
"""Replay proxy registry events -> final selector->impl map; compare to live state."""
import json, subprocess

ev = json.load(open("/home/heisenberg/CA/c-25/analysis/registry_events.json"))["result"]
ev = sorted(ev, key=lambda e: (int(e["blockNumber"], 16), int(e["logIndex"], 16)))

reg = {}   # selector -> impl
history = []
for e in ev:
    b = int(e["blockNumber"], 16)
    sel = e["topics"][1][2:10]
    d = e["data"][2:]
    old = "0x" + d[24:64]
    new = "0x" + d[88:128]
    old = "0x" + old[-40:] if any(c != "0" for c in old) else None
    new = "0x" + new[-40:] if any(c != "0" for c in new) else None
    prev = reg.get(sel)
    if new:
        reg[sel] = new
    else:
        reg.pop(sel, None)
    history.append({"block": b, "sel": sel, "old": prev, "new": new})

print("=== full history ===")
for h in history:
    print(f"{h['block']:>9} {h['sel']} {h['old']} -> {h['new']}")
print()
print("=== FINAL registry from events ===")
for s, i in sorted(reg.items()):
    print(f"0x{s} -> {i}")

# live check via getFunctionImplementation
def enc(sel): return "0x972fdd26" + sel + "00" * 28
import urllib.request
sels = sorted(reg.keys())
calls = [{"jsonrpc":"2.0","id":i+1,"method":"eth_call","params":[{"to":"0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756","data":enc(s)},"latest"]} for i,s in enumerate(sels)]
req = urllib.request.Request("https://ethereum-rpc.publicnode.com", data=json.dumps(calls).encode(),
    headers={"Content-Type":"application/json","User-Agent":"c25"})
out = json.loads(urllib.request.urlopen(req, timeout=60).read().decode())
byid = {o["id"]: o for o in out}
print()
print("=== LIVE registry vs replayed ===")
mismatch = 0
for i, s in enumerate(sels):
    o = byid.get(i+1, {})
    r = o.get("result")
    live = ("0x" + r[-40:]) if r and r != "0x" else None
    if (live or "").lower() != (reg[s] or "").lower():
        mismatch += 1
        print(f"MISMATCH 0x{s}: replayed={reg[s]} live={live}")
print(f"selectors: {len(sels)}, mismatches: {mismatch}")
json.dump({"final_registry": reg, "history": history},
          open("/home/heisenberg/CA/c-25/analysis/registry_replay.json", "w"), indent=2)
