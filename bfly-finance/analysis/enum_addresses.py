#!/usr/bin/env python3
"""Enumerate Starcoin token issuers + DeFi contract addresses for the whole-chain flash scan."""
import json, urllib.request

RPC = "https://main-seed.starcoin.org"
def call(method, params, timeout=60):
    body = json.dumps({"id": 1, "jsonrpc": "2.0", "method": method, "params": params}).encode()
    req = urllib.request.Request(RPC, data=body, headers={"Content-Type": "application/json", "User-Agent": "bfly-audit"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

addrs = {}
# known protocol / bridge addresses
known = {
    "starswap_dex": "0x8c109349c6bd91411d6bc962e080c4a3",
    "bfly": "0x4ffcc98f43ce74668264a0cf6eebe42b",
    "bfly_oracle": "0x82e35b34096f32c42061717c06e44a59",
    "bridged_xusdt_xeth_lockproxy": "0xe52552637c5897a2d499fbf08216f73e",
    "fai2_issuer": "0xfe125d419811297dfab03c61efec0bc9",
    "wen_issuer": "0xbf60b00855c92fe725296a436101c8c6",
}
addrs.update(known)

# token list from explorer
try:
    req = urllib.request.Request("https://doapi.stcscan.io/v2/token/main/stats/1", headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        d = json.loads(r.read())
    toks = d.get("contents", [])
    print("tokens:", len(toks))
    for t in toks[:60]:
        tt = t.get("type_tag", "")
        if "::" in tt:
            a = tt.split("::")[0].lower()
            addrs.setdefault(a, f"token:{tt[:60]}")
    for t in toks:
        tt = t.get("type_tag", "")
        if any(k in tt.lower() for k in ("lend", "loan", "flash", "borrow", "bank")):
            print("  suspicious token:", tt)
except Exception as e:
    print("explorer token list ERR", e)

# XETH address from ETHVaultPoolA imports (resolve via a view call type)
# ETH pool token: find via its VaultPool resource / event; try common addresses
for cand in ["0x00000000000000000000000000000001::XETH::XETH"]:
    r = call("contract.get_resource", ["0x4ffcc98f43ce74668264a0cf6eebe42b", f"0x1::Config::Config<0x4ffcc98f43ce74668264a0cf6eebe42b::Config::VaultPoolConfig<0x4ffcc98f43ce74668264a0cf6eebe42b::ETHVaultPoolA::VaultPool>>"])
    print("eth config present:", r.get("result") is not None)

print("\naddresses to scan:", len(addrs))
json.dump(addrs, open("scan_addresses.json", "w"), indent=1)
for k, v in addrs.items():
    print(f"  {k}: {v}")
