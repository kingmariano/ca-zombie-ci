#!/usr/bin/env python3
"""Decode WEN LendingPoolV2 resources + second BFly resources; fetch modules for CI disasm."""
import json, os, urllib.request

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

def le(hexs, n=None):
    b = bytes.fromhex(hexs[2:] if hexs.startswith("0x") else hexs)
    return int.from_bytes(b[:n] if n else b, "little")

WEN = "0xbf60b00855c92fe725296a436101c8c6"
FAI2 = "0xfe125d419811297dfab03c61efec0bc9"

res = call("state.list_resource", [WEN])["result"]["resources"]
print("=== WEN pool decoded ===")
for k, v in res.items():
    raw = v["raw"]
    if "Balance<" in k:
        print(f"  {k.split('::')[-1]}: {le(raw)/1e9:,.6f}")
    if "TotalCollateral<" in k:
        print(f"  TotalCollateral: {le(raw)/1e9:,.6f} (units {le(raw)})")
    if "TotalBorrow<" in k:
        print(f"  TotalBorrow: {le(raw)/1e9:,.6f} (units {le(raw)})")
    if "PoolInfo<" in k:
        b = bytes.fromhex(raw[2:]); print("  PoolInfo fields:", [int.from_bytes(b[i:i+16],'little') for i in range(0, 80, 16)])
    if "Rebase::Rebase" in k:
        b = bytes.fromhex(raw[2:]); print("  Rebase fields:", [int.from_bytes(b[i:i+16],'little') for i in range(0, 32, 16)])
    if "PoolOracle::Price" in k:
        b = bytes.fromhex(raw[2:]); print("  Oracle price raw:", b.hex())
    if "TokenInfo<" in k and "WEN" in k:
        b = bytes.fromhex(raw[2:]); print("  WEN total supply:", int.from_bytes(b[0:16],'little')/1e9)

print("\n=== second BFly resources ===")
res2 = call("state.list_resource", [FAI2])["result"]["resources"]
for k in sorted(res2):
    print("  ", k, "=", res2[k]["raw"][:80])

# fetch modules of extra protocols into analysis/extra_modules/<label>/
os.makedirs("extra_modules", exist_ok=True)
for label, addr in [("wen", WEN), ("fai2", FAI2), ("aww", "0x49142e24bf3b34b323b3bd339e2434e3"),
                    ("bridge", "0xe52552637c5897a2d499fbf08216f73e"), ("kiko", "0x8355417c88d969f656935244641256ad")]:
    d = os.path.join("extra_modules", label)
    os.makedirs(d, exist_ok=True)
    codes = call("state.list_code", [addr])["result"]["codes"]
    for name, v in codes.items():
        code = v["code"] if isinstance(v, dict) else v
        h = code[2:] if code.startswith("0x") else code
        open(os.path.join(d, name + ".mv"), "wb").write(bytes.fromhex(h))
    print(f"fetched {len(codes)} modules for {label}")
