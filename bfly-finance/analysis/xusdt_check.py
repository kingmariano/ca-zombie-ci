#!/usr/bin/env python3
"""Check XUSDT token provenance/legitimacy (read-only)."""
import json, urllib.request
RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

XU = "0xe52552637c5897a2d499fbf08216f73e"
ti = call("contract.get_resource", [XU, f"0x1::Token::TokenInfo<{XU}::XUSDT::XUSDT>"])
print("=== XUSDT TokenInfo (raw-ish) ===")
print(json.dumps(ti.get("result"), indent=1)[:2500])

mods = call("state.list_code", [XU])["result"]["codes"]
print("\nmodules at XUSDT addr:", list(mods.keys()))
for name, v in mods.items():
    b = bytes.fromhex(v["code"][2:])
    strs = []
    cur = b""
    for byte in b:
        if 32 <= byte < 127: cur += bytes([byte])
        else:
            if len(cur) >= 4: strs.append(cur.decode())
            cur = b""
    print(f"  {name}: {'|'.join(strs[:20])}")

# where does XUSDT live? check a recent transfer page
print("\n=== recent XUSDT transfers (explorer) ===")
try:
    req = urllib.request.Request("https://doapi.stcscan.io/v2/transaction/main/transfer/byTag/0xe52552637c5897a2d499fbf08216f73e::XUSDT::XUSDT/page/1",
                                 headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.loads(r.read())
    for t in d.get("contents", [])[:5]:
        print("  ", t.get("timestamp"), t.get("sender"), "->", t.get("receiver"), t.get("amount_value"))
except Exception as e:
    print("  ERR", e)
